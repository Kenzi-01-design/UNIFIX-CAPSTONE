import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
const allowedOrigins = (Deno.env.get('ADMIN_APP_ORIGINS') ?? '')
  .split(',')
  .map((origin) => origin.trim().replace(/\/$/, ''))
  .filter(Boolean);
const allowedRoles = new Set(['Admin', 'Assistant', 'Employee', 'Personnel']);

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

async function hash(value: string) {
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(value));
  return Array.from(new Uint8Array(digest), (byte) => byte.toString(16).padStart(2, '0')).join('');
}

function validText(value: unknown, maximum: number, required = false): value is string {
  return typeof value === 'string'
    && value.trim().length <= maximum
    && (!required || value.trim().length > 0);
}

Deno.serve(async (request) => {
  const origin = request.headers.get('origin') ?? '';
  if (!allowedOrigins.length) return new Response('Function is not configured.', { status: 503 });
  if (!allowedOrigins.includes(origin)) return new Response('Forbidden origin.', { status: 403 });
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders(origin) });
  if (request.method !== 'POST') return respond(origin, { error: 'Method not allowed.' }, 405);
  if (!supabaseUrl || !serviceRoleKey) {
    console.error('Admin invitation function is missing Supabase configuration.');
    return respond(origin, { error: 'Invitations are temporarily unavailable.' }, 503);
  }

  const token = request.headers.get('authorization')?.match(/^Bearer\s+(.+)$/i)?.[1];
  if (!token) return respond(origin, { error: 'Sign in as an administrator to continue.' }, 401);

  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false }
  });

  try {
    const { data: authData, error: authError } = await admin.auth.getUser(token);
    if (authError || !authData.user) return respond(origin, { error: 'Your session is invalid. Sign in again.' }, 401);

    const { data: actor, error: actorError } = await admin
      .from('user_profiles')
      .select('role,is_active')
      .eq('auth_user_id', authData.user.id)
      .maybeSingle();
    if (actorError) {
      console.error('Admin invitation caller profile lookup failed.');
      return respond(origin, { error: 'Unable to verify administrator access.' }, 503);
    }
    if (!actor?.is_active || !['Admin', 'Assistant'].includes(actor.role)) {
      return respond(origin, { error: 'Only active administrators and assistants may manage users.' }, 403);
    }

    const limitKey = await hash(`admin-create-user:${authData.user.id}`);
    const { data: allowed, error: rateError } = await admin.rpc('consume_public_endpoint_rate_limit', {
      p_key_hash: limitKey,
      p_limit: 5
    });
    if (rateError) {
      console.error('Admin invitation rate limiter failed.');
      return respond(origin, { error: 'Invitations are temporarily unavailable.' }, 503);
    }
    if (!allowed) return respond(origin, { error: 'Too many invitations. Try again in one minute.' }, 429);

    let payload: Record<string, unknown>;
    try {
      payload = await request.json();
    } catch {
      return respond(origin, { error: 'Enter valid invitation details.' }, 400);
    }
    if (!payload || typeof payload !== 'object' || Array.isArray(payload)) {
      return respond(origin, { error: 'Enter valid invitation details.' }, 400);
    }
    if (payload.action === 'delete') {
      const targetId = typeof payload.authUserId === 'string' ? payload.authUserId : '';
      if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(targetId)) {
        return respond(origin, { error: 'Choose a valid account to delete.' }, 400);
      }
      if (targetId === authData.user.id) {
        return respond(origin, { error: 'You cannot delete your own account.' }, 400);
      }

      const { data: target, error: targetError } = await admin
        .from('user_profiles')
        .select('id,auth_user_id,name,email,role,is_active')
        .eq('auth_user_id', targetId)
        .maybeSingle();
      if (targetError || !target) return respond(origin, { error: 'The selected account could not be found.' }, 404);
      if (target.role === 'Admin' && target.is_active) {
        const { count, error: adminCountError } = await admin
          .from('user_profiles')
          .select('id', { count: 'exact', head: true })
          .eq('role', 'Admin')
          .eq('is_active', true);
        if (adminCountError) {
          console.error('Active Admin count could not be checked.');
          return respond(origin, { error: 'Account deletion is temporarily unavailable.' }, 503);
        }
        if ((count ?? 0) <= 1) {
          return respond(origin, { error: 'The last active Admin account cannot be deleted.' }, 409);
        }
      }

      const { data: hasWorkHistory, error: historyError } = await admin.rpc('account_user_has_work_history', {
        p_auth_user_id: targetId
      });
      if (historyError) {
        console.error('Account work history could not be checked.');
        return respond(origin, { error: 'Account deletion is temporarily unavailable.' }, 503);
      }
      if (hasWorkHistory) {
        return respond(origin, {
          error: 'This account is linked to reports, requests, or assignments. Deactivate it instead to preserve work history.'
        }, 409);
      }

      const { error: requestAuditError } = await admin.from('account_audit_log').insert({
        actor_auth_user_id: authData.user.id,
        actor_email: authData.user.email ?? '',
        action: 'user_delete_requested',
        target_auth_user_id: targetId,
        target_email: target.email,
        details: { role: target.role }
      });
      if (requestAuditError) {
        console.error('Account deletion audit entry could not be written.');
        return respond(origin, { error: 'Account deletion is temporarily unavailable.' }, 503);
      }

      const { error: deleteError } = await admin.auth.admin.deleteUser(targetId);
      if (deleteError) {
        console.error('Auth account could not be deleted.');
        return respond(origin, { error: 'The account could not be deleted. Try again later.' }, 503);
      }
      const { error: cleanupError } = await admin
        .from('user_preferences')
        .delete()
        .eq('user_email', target.email);
      const { error: notificationsError } = await admin
        .from('notifications')
        .delete()
        .eq('user_email', target.email);
      const { error: deliveryCleanupError } = await admin
        .from('notification_deliveries')
        .delete()
        .eq('recipient', target.email);
      const { error: auditError } = await admin.from('account_audit_log').insert({
        actor_auth_user_id: authData.user.id,
        actor_email: authData.user.email ?? '',
        action: 'user_deleted',
        target_auth_user_id: targetId,
        target_email: target.email,
        details: { role: target.role }
      });
      if (cleanupError || notificationsError || deliveryCleanupError || auditError) {
        console.error('Account was deleted but related account cleanup or audit was incomplete.');
        return respond(origin, {
          error: 'The Auth account was deleted, but related account cleanup was incomplete. Contact the system administrator.'
        }, 503);
      }
      return respond(origin, { deleted: true });
    }
    if (payload.action && payload.action !== 'invite') {
      return respond(origin, { error: 'Choose a supported account action.' }, 400);
    }

    const name = typeof payload.name === 'string' ? payload.name.trim() : '';
    const email = typeof payload.email === 'string' ? payload.email.trim().toLowerCase() : '';
    const department = typeof payload.department === 'string' ? payload.department.trim() : '';
    const phone = typeof payload.phone === 'string' ? payload.phone.trim() : '';
    const location = typeof payload.location === 'string' ? payload.location.trim() : 'Main Campus';
    const role = payload.role;
    if (!validText(name, 120, true)
      || !validText(email, 254, true)
      || !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)
      || !validText(department, 160)
      || !validText(phone, 40)
      || !validText(location, 160)
      || typeof role !== 'string'
      || !allowedRoles.has(role)) {
      return respond(origin, { error: 'Check the name, email, contact details, and assigned role.' }, 400);
    }

    const { data: securitySettings, error: settingsError } = await admin
      .from('account_security_settings')
      .select('allowed_email_domains')
      .eq('singleton', true)
      .maybeSingle();
    if (settingsError || !securitySettings) {
      console.error('Admin invitation domain settings could not be loaded.');
      return respond(origin, { error: 'Invitations are temporarily unavailable.' }, 503);
    }
    const emailDomain = email.slice(email.lastIndexOf('@') + 1);
    const domains = Array.isArray(securitySettings.allowed_email_domains)
      ? securitySettings.allowed_email_domains.map((domain: string) => domain.trim().toLowerCase())
      : [];
    if (!domains.includes(emailDomain)) {
      return respond(origin, { error: 'Use an email address from an approved university domain.' }, 400);
    }

    const { data: inviteData, error: inviteError } = await admin.auth.admin.inviteUserByEmail(email, {
      data: { name, department, phone, location },
      redirectTo: origin
    });
    if (inviteError || !inviteData.user) {
      if (inviteError) console.error('Auth invitation could not be created.');
      return respond(origin, { error: 'The invitation could not be sent. Check the address or try again later.' }, 400);
    }

    const { error: profileError } = await admin
      .from('user_profiles')
      .update({
        name,
        email,
        role,
        department,
        phone,
        location,
        is_active: true,
        registration_status: 'approved',
        updated_at: new Date().toISOString()
      })
      .eq('auth_user_id', inviteData.user.id);
    if (profileError) {
      console.error('Invited user profile could not be activated.');
      return respond(origin, {
        error: 'The invite email was sent, but the profile could not be activated. The account remains pending for Admin review.'
      }, 503);
    }

    const { error: auditError } = await admin.from('account_audit_log').insert({
      actor_auth_user_id: authData.user.id,
      actor_email: authData.user.email ?? '',
      action: 'user_invited',
      target_auth_user_id: inviteData.user.id,
      target_email: email,
      details: { role }
    });
    if (auditError) {
      console.error('Admin invitation audit entry could not be written.');
      return respond(origin, {
        error: 'The invitation was sent, but its audit entry could not be saved. Contact the system administrator.'
      }, 503);
    }

    return respond(origin, { invited: true, message: 'Invitation email sent.' });
  } catch {
    console.error('Admin invitation request failed unexpectedly.');
    return respond(origin, { error: 'The invitation could not be completed. Try again later.' }, 500);
  }
});
