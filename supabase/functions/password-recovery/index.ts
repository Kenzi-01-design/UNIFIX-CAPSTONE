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

async function hashRecoveryCode(challengeId: string, code: string) {
  const key = await crypto.subtle.importKey(
    'raw',
    new TextEncoder().encode(serviceRoleKey),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign']
  );
  const signature = await crypto.subtle.sign(
    'HMAC',
    key,
    new TextEncoder().encode(`${challengeId}:${code}`)
  );
  return Array.from(new Uint8Array(signature), (byte) => byte.toString(16).padStart(2, '0')).join('');
}

function generateRecoveryCode() {
  const range = Math.floor(0x1_0000_0000 / 1_000_000) * 1_000_000;
  let value: number;
  do {
    value = crypto.getRandomValues(new Uint32Array(1))[0];
  } while (value >= range);
  return String(value % 1_000_000).padStart(6, '0');
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
  if (!supabaseUrl || !serviceRoleKey) {
    console.error('Password recovery function is missing Supabase configuration.');
    return response(origin, { error: 'Password recovery is temporarily unavailable.' }, 503);
  }

  let payload: Record<string, unknown>;
  try {
    payload = await request.json();
  } catch {
    return response(origin, { error: 'Enter valid recovery details.' }, 400);
  }
  const action = typeof payload?.action === 'string' ? payload.action : 'request-email';
  const email = typeof payload?.email === 'string' ? payload.email.trim().toLowerCase() : '';
  const phone = typeof payload?.phone === 'string' ? payload.phone.trim() : '';
  const challengeId = typeof payload?.challengeId === 'string' ? payload.challengeId : '';
  const code = typeof payload?.code === 'string' ? payload.code : '';
  const password = typeof payload?.password === 'string' ? payload.password : '';
  if (action === 'request-phone' && !/^[0-9]{11}$/.test(phone)) {
    return response(origin, { error: 'Enter the 11-digit phone number used during registration.' }, 400);
  }
  if (
    action === 'reset-phone'
    && (!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(challengeId)
      || !/^[0-9]{6}$/.test(code)
      || password.length < 8
      || password.length > 128)
  ) {
    return response(origin, { error: 'Enter a valid code and a password between 8 and 128 characters.' }, 400);
  }
  if (!['request-email', 'request-phone', 'reset-phone'].includes(action)) {
    return response(origin, { error: 'Choose a supported recovery method.' }, 400);
  }
  if (action === 'request-email' && (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email) || email.length > 254)) {
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

  if (action === 'request-phone') {
    const smsApiKey = Deno.env.get('SEMAPHORE_API_KEY') ?? '';
    const smsSenderName = Deno.env.get('SEMAPHORE_SENDER_NAME') ?? '';
    if (!smsApiKey || !smsSenderName) {
      console.error('SMS password recovery requires Semaphore provider configuration.');
      return response(origin, { error: 'Phone recovery is temporarily unavailable. Please use email recovery or try again later.' }, 503);
    }

    const phoneKey = await hash(`password-recovery:phone:${phone}`);
    const { data: phoneAllowed, error: phoneRateError } = await admin.rpc('consume_public_endpoint_rate_limit', {
      p_key_hash: phoneKey,
      p_limit: 3
    });
    if (phoneRateError) {
      console.error('Password recovery phone rate limiter failed.', phoneRateError);
      return response(origin, { error: 'Password recovery is temporarily unavailable.' }, 503);
    }
    if (!phoneAllowed) {
      return response(origin, { error: 'Too many recovery requests. Please wait a few minutes and try again.' }, 429);
    }

    const { data: profiles, error: profileError } = await admin
      .from('user_profiles')
      .select('auth_user_id')
      .eq('phone', phone)
      .eq('is_active', true)
      .eq('registration_status', 'approved')
      .limit(2);
    if (profileError) {
      console.error('Password recovery phone lookup failed.', profileError);
      return response(origin, { error: 'Password recovery is temporarily unavailable.' }, 503);
    }

    const requestId = crypto.randomUUID();
    if (profiles?.length === 1 && profiles[0].auth_user_id) {
      const recoveryCode = generateRecoveryCode();
      const { error: challengeError } = await admin
        .from('password_recovery_challenges')
        .upsert({
          challenge_id: requestId,
          auth_user_id: profiles[0].auth_user_id,
          code_hash: await hashRecoveryCode(requestId, recoveryCode),
          expires_at: new Date(Date.now() + 10 * 60 * 1000).toISOString(),
          attempt_count: 0
        }, { onConflict: 'auth_user_id' });
      if (challengeError) {
        console.error('Password recovery challenge could not be stored.', challengeError);
        return response(origin, { error: 'Password recovery is temporarily unavailable.' }, 503);
      }

      let smsResponse: Response;
      try {
        smsResponse = await fetch('https://api.semaphore.co/api/v4/messages', {
          method: 'POST',
          headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
          body: new URLSearchParams({
            apikey: smsApiKey,
            number: phone,
            message: `Your UNIFIX password reset code is ${recoveryCode}. It expires in 10 minutes. If you did not request this, ignore this message.`,
            sendername: smsSenderName
          })
        });
      } catch (error) {
        console.error('Could not reach the password recovery SMS provider.', error);
        const { error: deleteError } = await admin
          .from('password_recovery_challenges')
          .delete()
          .eq('challenge_id', requestId);
        if (deleteError) console.error('Unsent password recovery challenge could not be removed.', deleteError);
        return response(origin, { error: 'The recovery code could not be sent. Please try again later.' }, 502);
      }
      if (!smsResponse.ok) {
        console.error('The password recovery SMS provider rejected the message.', smsResponse.status);
        const { error: deleteError } = await admin
          .from('password_recovery_challenges')
          .delete()
          .eq('challenge_id', requestId);
        if (deleteError) console.error('Unsent password recovery challenge could not be removed.', deleteError);
        return response(origin, { error: 'The recovery code could not be sent. Please try again later.' }, 502);
      }
    }
    return response(origin, { sent: true, challengeId: requestId });
  }

  if (action === 'reset-phone') {
    const { data: authUserId, error: consumeError } = await admin.rpc('consume_password_recovery_challenge', {
      p_challenge_id: challengeId,
      p_code_hash: await hashRecoveryCode(challengeId, code)
    });
    if (consumeError) {
      console.error('Password recovery challenge could not be verified.', consumeError);
      return response(origin, { error: 'Password recovery is temporarily unavailable.' }, 503);
    }
    if (typeof authUserId !== 'string') {
      return response(origin, { error: 'The recovery code is invalid or expired. Request a new code and try again.' }, 400);
    }
    const { error: passwordError } = await admin.auth.admin.updateUserById(authUserId, { password });
    if (passwordError) {
      console.error('Password recovery could not update the account password.', passwordError);
      return response(origin, { error: 'The password could not be updated. Request a new code and try again.' }, 503);
    }
    return response(origin, { reset: true });
  }

  if (!resendApiKey || !fromEmail) {
    console.error('Email password recovery is missing email-provider configuration.');
    return response(origin, { error: 'Email recovery is temporarily unavailable.' }, 503);
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
