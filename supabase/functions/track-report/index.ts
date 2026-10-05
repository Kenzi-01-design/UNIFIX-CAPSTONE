// @ts-nocheck
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const allowedOrigins = (Deno.env.get('PUBLIC_APP_ORIGINS') || Deno.env.get('PUBLIC_APP_ORIGIN') || '')
  .split(',')
  .map((origin) => origin.trim().replace(/\/$/, ''))
  .filter(Boolean);
const maxRequestBytes = 16 * 1024;

function corsHeaders(origin: string) {
  const headers: Record<string, string> = {
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Content-Type': 'application/json',
    Vary: 'Origin'
  };
  if (allowedOrigins.includes(origin)) headers['Access-Control-Allow-Origin'] = origin;
  return headers;
}

function respond(origin: string, body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: corsHeaders(origin) });
}

function normalizeCode(value: unknown) {
  if (typeof value !== 'string') return '';
  return value.trim().toUpperCase();
}

async function readBoundedBody(request: Request, maxBytes: number) {
  const reader = request.body?.getReader();
  if (!reader) return '';
  const chunks: Uint8Array[] = [];
  let size = 0;
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    size += value.byteLength;
    if (size > maxBytes) {
      await reader.cancel().catch(() => undefined);
      throw new Error('BODY_TOO_LARGE');
    }
    chunks.push(value);
  }
  const bytes = new Uint8Array(size);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.byteLength;
  }
  return new TextDecoder('utf-8', { fatal: true }).decode(bytes);
}

async function rateLimitKey(request: Request) {
  const ip = request.headers.get('cf-connecting-ip')
    || request.headers.get('x-forwarded-for')?.split(',')[0]?.trim()
    || 'unknown';
  const bytes = new TextEncoder().encode(ip);
  const digest = await crypto.subtle.digest('SHA-256', bytes);
  return Array.from(new Uint8Array(digest), (byte) => byte.toString(16).padStart(2, '0')).join('');
}

Deno.serve(async (request) => {
  const origin = request.headers.get('origin') ?? '';
  if (!allowedOrigins.length) return new Response('Function is not configured.', { status: 500 });
  if (!allowedOrigins.includes(origin)) return new Response('Forbidden origin.', { status: 403 });
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders(origin) });
  if (request.method !== 'POST') return respond(origin, { error: 'Method not allowed.' }, 405);
  const contentLength = Number(request.headers.get('content-length') || 0);
  if (contentLength > maxRequestBytes) return respond(origin, { error: 'Request is too large.' }, 413);

  const admin = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
  );

  try {
    const keyHash = await rateLimitKey(request);
    const { data: allowed, error: rateError } = await admin.rpc('consume_public_endpoint_rate_limit', {
      p_key_hash: keyHash,
      p_limit: 10
    });
    if (rateError) {
      console.error('Public tracking rate limiter failed.', rateError);
      return respond(origin, { error: 'Tracking is temporarily unavailable.' }, 503);
    }
    if (!allowed) {
      return new Response(JSON.stringify({ error: 'Too many tracking attempts. Please try again in one minute.' }), {
        status: 429,
        headers: { ...corsHeaders(origin), 'Retry-After': '60' }
      });
    }

    let requestBody;
    try {
      requestBody = await readBoundedBody(request, maxRequestBytes);
    } catch (bodyError) {
      if (bodyError.message === 'BODY_TOO_LARGE') return respond(origin, { error: 'Request is too large.' }, 413);
      throw bodyError;
    }
    let payload;
    try {
      payload = JSON.parse(requestBody);
    } catch {
      return respond(origin, { error: 'The request body must contain valid JSON.' }, 400);
    }
    if (!payload || typeof payload !== 'object' || Array.isArray(payload)) {
      return respond(origin, { error: 'The request body must be a JSON object.' }, 400);
    }
    const { action, trackingCode, rating, comment } = payload;
    const code = normalizeCode(trackingCode);
    if (!/^UNI-\d{4}-\d{4,}$/.test(code)) {
      return respond(origin, { error: 'Enter a valid UNIFIX tracking code.' }, 400);
    }

    const { data: report, error: lookupError } = await admin
      .from('reports')
      .select('id, tracking_code, status, technician_state, assigned_personnel, created_at, updated_at, reviewed_at, assigned_at, in_progress_at, for_verification_at, completed_at, rework_count')
      .eq('tracking_code', code)
      .maybeSingle();
    if (lookupError) {
      console.error('Tracking lookup failed.', lookupError);
      return respond(origin, { error: 'Unable to look up this tracking code.' }, 500);
    }
    let workItem = report;
    if (!workItem) {
      const { data: requestItem, error: requestLookupError } = await admin
        .from('requests')
        .select('id, tracking_code, status, technician_state, assigned_personnel, created_at, updated_at, reviewed_at, assigned_at, in_progress_at, for_verification_at, completed_at, rework_count')
        .eq('tracking_code', code)
        .maybeSingle();
      if (requestLookupError) {
        console.error('Request tracking lookup failed.', requestLookupError);
        return respond(origin, { error: 'Unable to look up this tracking code.' }, 500);
      }
      workItem = requestItem;
    }
    if (!workItem) return respond(origin, { error: 'No report or request was found for that tracking code.' }, 404);

    if (action === 'reopen') {
      const reason = typeof payload.reason === 'string' ? payload.reason.trim() : '';
      if (reason.length < 5 || reason.length > 500) {
        return respond(origin, { error: 'Provide a reopen reason between 5 and 500 characters.' }, 400);
      }
      if (workItem.status !== 'closed' || !workItem.completed_at
        || new Date(workItem.completed_at).getTime() < Date.now() - 7 * 24 * 60 * 60 * 1000) {
        return respond(origin, { error: 'This work item can no longer be reopened.' }, 409);
      }
      const patch = {
        status: 'in-progress',
        reopen_reason: reason,
        reopened_at: new Date().toISOString(),
        rework_count: (workItem.rework_count || 0) + 1,
        technician_state: Array.isArray(workItem.assigned_personnel) && workItem.assigned_personnel.length
          ? 'assigned'
          : 'unassigned'
      };
      const table = report ? 'reports' : 'requests';
      const { data: reopenedItem, error: reopenError } = await admin
        .from(table)
        .update(patch)
        .eq('id', workItem.id)
        .eq('tracking_code', code)
        .eq('status', 'closed')
        .select('id')
        .maybeSingle();
      if (reopenError) {
        console.error('Public work item reopen failed.', reopenError);
        return respond(origin, { error: 'Unable to reopen this work item.' }, 500);
      }
      if (!reopenedItem) return respond(origin, { error: 'This work item has already changed and cannot be reopened.' }, 409);
      return respond(origin, { submitted: true });
    }

    if (action === 'feedback') {
      if (!report) return respond(origin, { error: 'Feedback is available only for completed reports.' }, 400);
      const numericRating = Number(rating);
      const safeComment = typeof comment === 'string' ? comment.trim() : '';
      if (!Number.isInteger(numericRating) || numericRating < 1 || numericRating > 5 || safeComment.length > 500) {
        return respond(origin, { error: 'Provide a rating from 1 to 5 and a comment of at most 500 characters.' }, 400);
      }
      if (workItem.status !== 'closed' && workItem.status !== 'resolved') {
        return respond(origin, { error: 'Feedback is available after completed work has been verified.' }, 409);
      }

      const { error: feedbackError } = await admin.from('report_feedback').insert({
        report_id: workItem.id,
        reporter_email: null,
        rating: numericRating,
        comment: safeComment
      });
      if (feedbackError) {
        if (feedbackError.code === '23505') {
          return respond(origin, { error: 'Feedback has already been submitted for this report.' }, 409);
        }
        console.error('Public report feedback could not be saved.', feedbackError);
        return respond(origin, { error: 'Unable to save feedback.' }, 500);
      }
      return respond(origin, { submitted: true });
    }

    if (action !== 'lookup') return respond(origin, { error: 'Unknown tracking action.' }, 400);

    let feedback = null;
    if (report) {
      const { data, error: feedbackLookupError } = await admin
        .from('report_feedback')
        .select('id')
        .eq('report_id', workItem.id)
        .maybeSingle();
      if (feedbackLookupError) {
        console.error('Feedback status lookup failed.', feedbackLookupError);
        return respond(origin, { error: 'Unable to retrieve report status.' }, 500);
      }
      feedback = data;
    }

    const submittedAt = workItem.created_at;
    const steps = [
      { label: 'Submitted', at: submittedAt },
      { label: 'Reviewed', at: workItem.reviewed_at },
      { label: 'Assigned', at: workItem.assigned_at },
      { label: 'In progress', at: workItem.in_progress_at },
      { label: 'For verification', at: workItem.for_verification_at },
      { label: 'Completed', at: workItem.completed_at }
    ].map((step) => ({ ...step, complete: Boolean(step.at) }));
    const isCompleted = ['closed', 'resolved', 'action-taken'].includes(workItem.status);
    const hasAssignment = Array.isArray(workItem.assigned_personnel) && workItem.assigned_personnel.length > 0;
    const status = isCompleted
      ? 'Completed'
      : workItem.technician_state === 'started' || workItem.status === 'in-progress'
        ? 'In progress'
        : workItem.status === 'for-verification'
          ? 'For verification'
        : hasAssignment
          ? 'Assigned'
          : workItem.reviewed_at
            ? 'Reviewed'
            : 'Submitted';

    return respond(origin, {
      workItem: {
        trackingCode: workItem.tracking_code,
        status,
        entityType: report ? 'report' : 'request',
        assignedTeam: hasAssignment ? 'Campus Maintenance Team' : null,
        lastUpdated: workItem.updated_at,
        completed: isCompleted,
        feedbackSubmitted: Boolean(feedback),
        feedbackEligible: Boolean(report),
        canReopen: workItem.status === 'closed' && Boolean(workItem.completed_at)
          && new Date(workItem.completed_at).getTime() >= Date.now() - 7 * 24 * 60 * 60 * 1000,
        timeline: steps
      }
    });
  } catch (error) {
    console.error('Public tracking function error.', error);
    return respond(origin, { error: 'Could not process the tracking request.' }, 500);
  }
});
