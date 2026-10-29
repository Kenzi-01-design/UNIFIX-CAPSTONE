import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
const allowedOrigins = (Deno.env.get('ADMIN_APP_ORIGINS') ?? '')
  .split(',')
  .map((origin) => origin.trim().replace(/\/$/, ''))
  .filter(Boolean);

function respond(origin: string, body: Record<string, unknown>, status = 200) {
  const headers: Record<string, string> = {
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Content-Type': 'application/json',
    Vary: 'Origin'
  };
  if (allowedOrigins.includes(origin)) headers['Access-Control-Allow-Origin'] = origin;
  return new Response(JSON.stringify(body), { status, headers });
}

async function hash(value: string) {
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(value));
  return Array.from(new Uint8Array(digest), (byte) => byte.toString(16).padStart(2, '0')).join('');
}

Deno.serve(async (request) => {
  const origin = request.headers.get('origin') ?? '';
  if (!allowedOrigins.length) return new Response('Function is not configured.', { status: 503 });
  if (!allowedOrigins.includes(origin)) return new Response('Forbidden origin.', { status: 403 });
  if (request.method === 'OPTIONS') return new Response('ok', { headers: respond(origin, {}).headers });
  if (request.method !== 'POST') return respond(origin, { error: 'Method not allowed.' }, 405);
  if (Number(request.headers.get('content-length') || 0) > 4 * 1024) {
    return respond(origin, { error: 'The password update request is too large.' }, 413);
  }
  if (!supabaseUrl || !serviceRoleKey) {
    console.error('Admin password update is missing Supabase configuration.');
    return respond(origin, { error: 'Password updates are temporarily unavailable.' }, 503);
  }

  const token = request.headers.get('authorization')?.match(/^Bearer\s+(.+)$/i)?.[1];
  if (!token) return respond(origin, { error: 'Sign in as an Admin to continue.' }, 401);

  let payload: Record<string, unknown>;
  try {
    payload = await request.json();
  } catch {
    return respond(origin, { error: 'Enter valid password update details.' }, 400);
  }
  if (!payload || typeof payload !== 'object' || Array.isArray(payload)) {
    return respond(origin, { error: 'Enter valid password update details.' }, 400);
  }
  const targetAuthUserId = typeof payload.targetAuthUserId === 'string' ? payload.targetAuthUserId : '';
  const password = typeof payload.password === 'string' ? payload.password : '';
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(targetAuthUserId)) {
    return respond(origin, { error: 'Choose a valid university account.' }, 400);
  }
  if (password.length < 8 || password.length > 128) {
    return respond(origin, { error: 'The new password must be between 8 and 128 characters.' }, 400);
  }

  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false }
  });
  const { data: authData, error: authError } = await admin.auth.getUser(token);
  if (authError || !authData.user) return respond(origin, { error: 'Your session is invalid. Sign in again.' }, 401);

  const { data: actor, error: actorError } = await admin
    .from('user_profiles')
    .select('role,is_active')
    .eq('auth_user_id', authData.user.id)
    .maybeSingle();
  if (actorError) {
    console.error('Admin password update caller could not be verified.', actorError);
    return respond(origin, { error: 'Unable to verify Admin access.' }, 503);
  }
  if (!actor?.is_active || actor.role !== 'Admin') {
    return respond(origin, { error: 'Only an active Admin may update user passwords.' }, 403);
  }

  const rateKey = await hash(`admin-set-user-password:${authData.user.id}`);
  const { data: allowed, error: rateError } = await admin.rpc('consume_public_endpoint_rate_limit', {
    p_key_hash: rateKey,
    p_limit: 10
  });
  if (rateError) {
    console.error('Admin password update rate limiter failed.', rateError);
    return respond(origin, { error: 'Password updates are temporarily unavailable.' }, 503);
  }
  if (!allowed) return respond(origin, { error: 'Too many password updates. Try again in one minute.' }, 429);

  const { data: target, error: targetError } = await admin
    .from('user_profiles')
    .select('email,is_active,registration_status')
    .eq('auth_user_id', targetAuthUserId)
    .maybeSingle();
  if (targetError) {
    console.error('Target account for Admin password update could not be loaded.', targetError);
    return respond(origin, { error: 'The selected account could not be checked.' }, 503);
  }
  if (!target) return respond(origin, { error: 'The selected account could not be found.' }, 404);
  if (!target.is_active || target.registration_status !== 'approved') {
    return respond(origin, { error: 'Only active, approved accounts can have their password updated.' }, 409);
  }

  const { error: passwordError } = await admin.auth.admin.updateUserById(targetAuthUserId, { password });
  if (passwordError) {
    console.error('Admin password update was rejected by Auth.', passwordError);
    return respond(origin, { error: 'The password could not be updated. Check the password and try again.' }, 400);
  }

  const { error: auditError } = await admin.from('account_audit_log').insert({
    actor_auth_user_id: authData.user.id,
    actor_email: authData.user.email ?? '',
    action: 'admin_password_updated',
    target_auth_user_id: targetAuthUserId,
    target_email: target.email,
    details: {}
  });
  if (auditError) {
    console.error('Password was updated but the Admin password change could not be audited.', auditError);
    return respond(origin, {
      error: 'The password was updated, but its audit record could not be saved. Contact the system administrator.'
    }, 503);
  }

  return respond(origin, { updated: true });
});
