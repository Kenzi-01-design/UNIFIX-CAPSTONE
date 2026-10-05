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

    const requestBody = await request.text();
    if (new TextEncoder().encode(requestBody).byteLength > maxRequestBytes) {
      return respond(origin, { error: 'Request is too large.' }, 413);
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
      .select('id, tracking_code, status, technician_state, assigned_personnel, created_at, updated_at, reviewed_at, assigned_at, in_progress_at, completed_at')
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
        .select('id, tracking_code, status, technician_state, assigned_personnel, created_at, updated_at, reviewed_at, assigned_at, in_progress_at, completed_at')
        .eq('tracking_code', code)
        .maybeSingle();
      if (requestLookupError) {
        console.error('Request tracking lookup failed.', requestLookupError);
        return respond(origin, { error: 'Unable to look up this tracking code.' }, 500);
      }
      workItem = requestItem;
    }
    if (!workItem) return respond(origin, { error: 'No report or request was found for that tracking code.' }, 404);

    if (action === 'feedback') {
      if (!report) return respond(origin, { error: 'Feedback is available only for completed reports.' }, 400);
      const numericRating = Number(rating);
      const safeComment = typeof comment === 'string' ? comment.trim() : '';
      if (!Number.isInteger(numericRating) || numericRating < 1 || numericRating > 5 || safeComment.length > 500) {
        return respond(origin, { error: 'Provide a rating from 1 to 5 and a comment of at most 500 characters.' }, 400);
      }
      if (workItem.status !== 'resolved' && workItem.status !== 'action-taken' && workItem.technician_state !== 'completed') {
        return respond(origin, { error: 'Feedback is available after the work is completed.' }, 409);
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
      { label: 'Completed', at: workItem.completed_at }
    ].map((step) => ({ ...step, complete: Boolean(step.at) }));
    const isCompleted = workItem.status === 'resolved' || workItem.status === 'action-taken' || workItem.technician_state === 'completed';
    const hasAssignment = Array.isArray(workItem.assigned_personnel) && workItem.assigned_personnel.length > 0;
    const status = isCompleted
      ? 'Completed'
      : workItem.technician_state === 'started' || workItem.status === 'in-progress'
        ? 'In progress'
        : hasAssignment
          ? 'Assigned'
          : workItem.reviewed_at
            ? 'Reviewed'
            : 'Submitted';

    return respond(origin, {
      workItem: {
        trackingCode: workItem.tracking_code,
        status,
        assignedTeam: hasAssignment ? 'Campus Maintenance Team' : null,
        lastUpdated: workItem.updated_at,
        completed: isCompleted,
        feedbackSubmitted: Boolean(feedback),
        feedbackEligible: Boolean(report),
        timeline: steps
      }
    });
  } catch (error) {
    console.error('Public tracking function error.', error);
    return respond(origin, { error: 'Could not process the tracking request.' }, 500);
  }
});
