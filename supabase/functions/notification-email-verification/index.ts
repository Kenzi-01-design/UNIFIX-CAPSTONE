import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
const anonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? '';
const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
const resendApiKey = Deno.env.get('RESEND_API_KEY') ?? '';
const fromEmail = Deno.env.get('NOTIFICATION_FROM_EMAIL') ?? '';
const allowedOrigins = (Deno.env.get('NOTIFICATION_APP_ORIGINS') ?? Deno.env.get('ADMIN_APP_ORIGINS') ?? '')
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

async function hashToken(token: string) {
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(token));
  return Array.from(new Uint8Array(digest), (byte) => byte.toString(16).padStart(2, '0')).join('');
}

Deno.serve(async (request) => {
  const origin = request.headers.get('origin') ?? '';
  if (!allowedOrigins.length) return new Response('Function is not configured.', { status: 503 });
  if (!allowedOrigins.includes(origin)) return new Response('Forbidden origin.', { status: 403 });
  if (request.method === 'OPTIONS') return new Response('ok', { headers: response(origin, {}).headers });
  if (request.method !== 'POST') return response(origin, { error: 'Method not allowed.' }, 405);
  if (!supabaseUrl || !anonKey || !serviceRoleKey) {
    console.error('Notification email verification function is missing Supabase configuration.');
    return response(origin, { error: 'Notification email verification is temporarily unavailable.' }, 503);
  }

  let payload: Record<string, unknown>;
  try {
    payload = await request.json();
  } catch {
    return response(origin, { error: 'Enter valid verification details.' }, 400);
  }
  if (!payload || typeof payload !== 'object' || Array.isArray(payload)) {
    return response(origin, { error: 'Enter valid verification details.' }, 400);
  }

  const action = payload.action;
  if (action === 'request') {
    const bearer = request.headers.get('authorization')?.match(/^Bearer\s+(.+)$/i)?.[1];
    const email = typeof payload.email === 'string' ? payload.email.trim().toLowerCase() : '';
    if (!bearer) return response(origin, { error: 'Sign in before setting a notification email.' }, 401);
    if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email) || email.length > 254) {
      return response(origin, { error: 'Enter a valid notification email address.' }, 400);
    }
    if (!resendApiKey || !fromEmail) {
      console.error('Notification email verification requires the Resend email provider configuration.');
      return response(origin, { error: 'Notification email verification is temporarily unavailable.' }, 503);
    }

    const userClient = createClient(supabaseUrl, anonKey, {
      auth: { autoRefreshToken: false, persistSession: false },
      global: { headers: { Authorization: `Bearer ${bearer}` } }
    });
    const { data: authData, error: authError } = await userClient.auth.getUser(bearer);
    if (authError || !authData.user) {
      return response(origin, { error: 'Sign in before setting a notification email.' }, 401);
    }

    const serviceClient = createClient(supabaseUrl, serviceRoleKey, {
      auth: { autoRefreshToken: false, persistSession: false }
    });
    const { data, error } = await serviceClient.rpc('begin_notification_email_verification', {
      p_email: email,
      p_auth_user_id: authData.user.id
    });
    if (error || !data?.[0]?.token) {
      const message = error?.message || 'The verification request could not be started.';
      const status = /sign in/i.test(message) ? 401 : /wait one minute/i.test(message) ? 429 : 400;
      return response(origin, { error: message }, status);
    }

    const verificationUrl = new URL(origin);
    verificationUrl.searchParams.set('verify-notification-email', data[0].token);
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
          subject: 'Verify your UNIFIX notification email',
          text: `Use this link within 30 minutes to verify the email address for UNIFIX work updates:\n\n${verificationUrl.toString()}\n\nIf you did not request this, you can ignore this message.`
        })
      });
    } catch (error) {
      console.error('Could not reach the notification email provider.', error);
      return response(origin, { error: 'The verification email could not be sent. Try again shortly.' }, 502);
    }
    if (!emailResponse.ok) {
      console.error('Resend rejected a notification email verification message.', emailResponse.status);
      return response(origin, { error: 'The verification email could not be sent. Try again shortly.' }, 502);
    }
    return response(origin, { sent: true });
  }

  if (action === 'verify') {
    const token = typeof payload.token === 'string' ? payload.token : '';
    if (!/^[0-9a-f]{128}$/i.test(token)) {
      return response(origin, { error: 'This verification link is invalid or expired. Request a new one in Settings.' }, 400);
    }
    const serviceClient = createClient(supabaseUrl, serviceRoleKey, {
      auth: { autoRefreshToken: false, persistSession: false }
    });
    const { data: email, error } = await serviceClient.rpc('complete_notification_email_verification', {
      p_token_hash: await hashToken(token)
    });
    if (error || typeof email !== 'string') {
      return response(origin, {
        error: 'This verification link is invalid or expired. Request a new one in Settings.'
      }, 400);
    }
    return response(origin, { verified: true, email });
  }

  return response(origin, { error: 'Choose a supported verification action.' }, 400);
});
