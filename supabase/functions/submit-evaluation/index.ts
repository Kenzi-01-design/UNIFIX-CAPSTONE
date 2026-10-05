// @ts-nocheck
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const allowedOrigins = (Deno.env.get('PUBLIC_APP_ORIGINS') || Deno.env.get('PUBLIC_APP_ORIGIN') || '')
  .split(',')
  .map((origin) => origin.trim().replace(/\/$/, ''))
  .filter(Boolean);
const roles = new Set(['Public', 'Employee', 'Assistant', 'Personnel', 'Admin', 'Student']);
const isoCharacteristics = [
  'functionalSuitability', 'performanceEfficiency', 'compatibility', 'usability',
  'reliability', 'security', 'maintainability', 'portability'
];

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

function response(origin: string, body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: corsHeaders(origin) });
}

function validAnswers(payload: any) {
  return Array.isArray(payload.susAnswers)
    && payload.susAnswers.length === 10
    && payload.susAnswers.every((answer: unknown) => Number.isInteger(answer) && answer >= 1 && answer <= 5)
    && payload.isoAnswers
    && typeof payload.isoAnswers === 'object'
    && !Array.isArray(payload.isoAnswers)
    && Object.keys(payload.isoAnswers).length === isoCharacteristics.length
    && isoCharacteristics.every((key) => Number.isInteger(payload.isoAnswers[key])
      && payload.isoAnswers[key] >= 1 && payload.isoAnswers[key] <= 5);
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
    || request.headers.get('x-forwarded-for')?.split(',')[0]?.trim();
  if (!ip) return null;
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(`evaluation:${ip}`));
  return Array.from(new Uint8Array(digest), (byte) => byte.toString(16).padStart(2, '0')).join('');
}

Deno.serve(async (request) => {
  const origin = request.headers.get('origin') ?? '';
  if (!allowedOrigins.length) return new Response('Function is not configured.', { status: 500 });
  if (!allowedOrigins.includes(origin)) return new Response('Forbidden origin.', { status: 403 });
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders(origin) });
  if (request.method !== 'POST') return response(origin, { error: 'Method not allowed.' }, 405);
  if (Number(request.headers.get('content-length') || 0) > 8 * 1024) {
    return response(origin, { error: 'Evaluation response is too large.' }, 413);
  }

  const admin = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
  );

  try {
    const keyHash = await rateLimitKey(request);
    if (!keyHash) return response(origin, { error: 'Could not verify the request source.' }, 503);
    const { data: allowed, error: rateError } = await admin.rpc('consume_public_endpoint_rate_limit', {
      p_key_hash: keyHash,
      p_limit: 5
    });
    if (rateError) {
      console.error('Evaluation rate limiter failed.', rateError);
      return response(origin, { error: 'Evaluation is temporarily unavailable.' }, 503);
    }
    if (!allowed) {
      return new Response(JSON.stringify({ error: 'Too many evaluation submissions. Please try again later.' }), {
        status: 429,
        headers: { ...corsHeaders(origin), 'Retry-After': '60' }
      });
    }

    let rawBody;
    try {
      rawBody = await readBoundedBody(request, 8 * 1024);
    } catch (bodyError) {
      if (bodyError.message === 'BODY_TOO_LARGE') {
        return response(origin, { error: 'Evaluation response is too large.' }, 413);
      }
      throw bodyError;
    }
    let payload;
    try {
      payload = JSON.parse(rawBody);
    } catch {
      return response(origin, { error: 'The request body must contain valid JSON.' }, 400);
    }
    if (!payload || typeof payload !== 'object' || Array.isArray(payload)
      || !roles.has(payload.respondentRole)
      || !validAnswers(payload)
      || typeof payload.submissionKey !== 'string'
      || !/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(payload.submissionKey)) {
      return response(origin, { error: 'The evaluation response contains invalid answers.' }, 400);
    }

    const { error } = await admin.from('evaluation_responses').insert({
      submission_key: payload.submissionKey,
      respondent_role: payload.respondentRole,
      sus_answers: payload.susAnswers,
      iso_answers: payload.isoAnswers
    });
    if (error) {
      if (error.code === '23505') return response(origin, { error: 'This evaluation response was already received.' }, 409);
      console.error('Evaluation response insert failed.', error);
      return response(origin, { error: 'Could not save the evaluation response.' }, 500);
    }
    return response(origin, { submitted: true });
  } catch (error) {
    console.error('Evaluation submission failed.', error);
    return response(origin, { error: 'Could not process the evaluation response.' }, 500);
  }
});
