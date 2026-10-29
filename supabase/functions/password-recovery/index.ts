import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
const resendApiKey = Deno.env.get('RESEND_API_KEY') ?? '';
const fromEmail = Deno.env.get('NOTIFICATION_FROM_EMAIL') ?? '';
const allowedOrigins = (
  Deno.env.get('PASSWORD_RECOVERY_APP_ORIGINS')
  ?? Deno.env.get('NOTIFICATION_APP_ORIGINS')
  ?? ''
)
  .split(',')
  .map((origin) => origin.trim().replace(/\/$/, ''))
  .filter(Boolean);

function response(origin: string, body: Record<string, unknown>, status = 200) {
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
  if (request.method === 'OPTIONS') return new Response('ok', { headers: response(origin, {}).headers });
  if (request.method !== 'POST') return response(origin, { error: 'Method not allowed.' }, 405);
  if (Number(request.headers.get('content-length') || 0) > 4 * 1024) {
    return response(origin, { error: 'The recovery request is too large.' }, 413);
  }
  if (!supabaseUrl || !serviceRoleKey || !resendApiKey || !fromEmail) {
    console.error('Password recovery function is missing Supabase or email-provider configuration.');
    return response(origin, { error: 'Password recovery is temporarily unavailable.' }, 503);
  }

  let payload: Record<string, unknown>;
  try {
    payload = await request.json();
  } catch {
    return response(origin, { error: 'Enter a valid email address.' }, 400);
  }
  const email = typeof payload?.email === 'string' ? payload.email.trim().toLowerCase() : '';
  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email) || email.length > 254) {
    return response(origin, { error: 'Enter a valid email address.' }, 400);
  }

  const clientIp = request.headers.get('cf-connecting-ip');
  if (!clientIp) {
    console.error('Password recovery request did not include a trusted client IP.');
    return response(origin, { error: 'Password recovery is temporarily unavailable.' }, 503);
  }

  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false }
  });
  const ipKey = await hash(`password-recovery:ip:${clientIp}`);
  const { data: ipAllowed, error: ipRateError } = await admin.rpc('consume_public_endpoint_rate_limit', {
    p_key_hash: ipKey,
    p_limit: 10
  });
  if (ipRateError) {
    console.error('Password recovery IP rate limiter failed.', ipRateError);
    return response(origin, { error: 'Password recovery is temporarily unavailable.' }, 503);
  }
  if (!ipAllowed) {
    return response(origin, { error: 'Too many recovery requests. Please wait a few minutes and try again.' }, 429);
  }

  const emailKey = await hash(`password-recovery:email:${email}`);
  const { data: emailAllowed, error: emailRateError } = await admin.rpc('consume_public_endpoint_rate_limit', {
    p_key_hash: emailKey,
    p_limit: 3
  });
  if (emailRateError) {
    console.error('Password recovery email rate limiter failed.', emailRateError);
    return response(origin, { error: 'Password recovery is temporarily unavailable.' }, 503);
  }
  if (!emailAllowed) {
    return response(origin, { error: 'Too many recovery requests. Please wait a few minutes and try again.' }, 429);
  }

  const { data: preferences, error: preferencesError } = await admin
    .from('user_preferences')
    .select('user_email')
    .eq('notification_email', email)
    .eq('notification_email_verified', true)
    .limit(2);
  if (preferencesError) {
    console.error('Password recovery address lookup failed.', preferencesError);
    return response(origin, { error: 'Password recovery is temporarily unavailable.' }, 503);
  }
  if (preferences?.length !== 1) return response(origin, { sent: true });

  const { data: profiles, error: profileError } = await admin
    .from('user_profiles')
    .select('auth_user_id,email')
    .ilike('email', preferences[0].user_email.replace(/[\\%_]/g, '\\$&'))
    .eq('is_active', true)
    .eq('registration_status', 'approved')
    .limit(2);
  if (profileError) {
    console.error('Password recovery account lookup failed.', profileError);
    return response(origin, { error: 'Password recovery is temporarily unavailable.' }, 503);
  }
  if (profiles?.length !== 1 || !profiles[0].auth_user_id) return response(origin, { sent: true });

  const { data: authResult, error: authError } = await admin.auth.admin.getUserById(profiles[0].auth_user_id);
  if (authError || !authResult.user?.email) {
    console.error('Password recovery could not retrieve the account identity.', authError);
    return response(origin, { error: 'Password recovery is temporarily unavailable.' }, 503);
  }

  const { data: linkData, error: linkError } = await admin.auth.admin.generateLink({
    type: 'recovery',
    email: authResult.user.email,
    options: { redirectTo: origin }
  });
  if (linkError || !linkData.properties?.action_link) {
    console.error('Password recovery link generation failed.', linkError);
    return response(origin, { error: 'Password recovery is temporarily unavailable.' }, 503);
  }

  let emailResponse: Response;
  try {
    emailResponse = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${resendApiKey}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        from: fromEmail,
        to: [email],
        subject: 'Reset your UNIFIX password',
        text: `A password reset was requested for your UNIFIX account. Use this link to choose a new password:\n\n${linkData.properties.action_link}\n\nIf you did not request this, you can ignore this message.`
      })
    });
  } catch (error) {
    console.error('Could not reach the password recovery email provider.', error);
    return response(origin, { error: 'The recovery email could not be sent. Please try again later.' }, 502);
  }
  if (!emailResponse.ok) {
    console.error('The password recovery email provider rejected the message.', emailResponse.status);
    return response(origin, { error: 'The recovery email could not be sent. Please try again later.' }, 502);
  }

  return response(origin, { sent: true });
});
