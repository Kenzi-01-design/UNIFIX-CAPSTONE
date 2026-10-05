// @ts-nocheck
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
const webhookSecret = Deno.env.get('NOTIFICATION_WEBHOOK_SECRET') ?? '';
const client = createClient(supabaseUrl, serviceRoleKey);

function authorized(request: Request) {
  const bearer = request.headers.get('authorization')?.replace(/^Bearer\s+/i, '');
  return Boolean(webhookSecret) && (
    bearer === webhookSecret || request.headers.get('x-notification-secret') === webhookSecret
  );
}

async function deliver(id: string) {
  const { data: delivery, error: readError } = await client
    .from('notification_deliveries')
    .select('*')
    .eq('id', id)
    .maybeSingle();
  if (readError) throw readError;
  if (!delivery) throw new Error('Notification delivery not found.');
  if (delivery.status === 'sent' || delivery.status === 'processing') return;

  const { data: claimed, error: claimError } = await client
    .from('notification_deliveries')
    .update({
      status: 'processing',
      attempt_count: delivery.attempt_count + 1,
      last_error: null
    })
    .eq('id', id)
    .in('status', ['pending', 'failed'])
    .select('*')
    .maybeSingle();
  if (claimError) throw claimError;
  if (!claimed) return;

  try {
    if (claimed.channel === 'email') {
      const apiKey = Deno.env.get('RESEND_API_KEY');
      const from = Deno.env.get('NOTIFICATION_FROM_EMAIL');
      if (!apiKey || !from) throw new Error('Email delivery is not configured.');
      const response = await fetch('https://api.resend.com/emails', {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${apiKey}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          from,
          to: [claimed.recipient],
          subject: claimed.subject,
          text: claimed.body
        })
      });
      if (!response.ok) throw new Error(`Email provider rejected the message (${response.status}).`);
    } else {
      const apiKey = Deno.env.get('SEMAPHORE_API_KEY');
      const senderName = Deno.env.get('SEMAPHORE_SENDER_NAME');
      if (!apiKey || !senderName) throw new Error('SMS delivery is not configured.');
      const response = await fetch('https://api.semaphore.co/api/v4/messages', {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams({
          apikey: apiKey,
          number: claimed.recipient,
          message: claimed.body,
          sendername: senderName
        })
      });
      if (!response.ok) throw new Error(`SMS provider rejected the message (${response.status}).`);
    }

    const { error: sentError } = await client
      .from('notification_deliveries')
      .update({ status: 'sent', sent_at: new Date().toISOString(), last_error: null })
      .eq('id', id)
      .eq('status', 'processing');
    if (sentError) throw sentError;
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Notification delivery failed.';
    const { error: updateError } = await client
      .from('notification_deliveries')
      .update({ status: 'failed', last_error: message.slice(0, 1000) })
      .eq('id', id)
      .eq('status', 'processing');
    if (updateError) console.error('Could not save notification delivery failure.', updateError);
    throw error;
  }
}

async function queueOverdueNotifications() {
  const now = new Date().toISOString();
  const dayKey = now.slice(0, 10);
  const activeStatuses = '("closed","resolved","action-taken")';
  const [reportsResult, requestsResult, adminsResult] = await Promise.all([
    client.from('reports').select('id,title,due_at,tracking_code,status').lt('due_at', now).not('status', 'in', activeStatuses),
    client.from('requests').select('id,title,due_at,tracking_code,status').lt('due_at', now).not('status', 'in', activeStatuses),
    client.from('user_profiles').select('email,phone').eq('role', 'Admin').eq('is_active', true)
  ]);
  for (const result of [reportsResult, requestsResult, adminsResult]) {
    if (result.error) throw result.error;
  }

  const workItems = [
    ...(reportsResult.data || []).map((item) => ({ ...item, entity_type: 'report' })),
    ...(requestsResult.data || []).map((item) => ({ ...item, entity_type: 'request' }))
  ];
  const admins = adminsResult.data || [];
  let queued = 0;

  for (const admin of admins) {
    const { data: preferences, error: preferenceError } = await client
      .from('user_preferences')
      .select('inapp_notifications,email_notifications,sms_notifications')
      .eq('user_email', admin.email)
      .maybeSingle();
    if (preferenceError) throw preferenceError;

    for (const item of workItems) {
      const dedupe = `overdue:${dayKey}:${item.entity_type}:${item.id}:${admin.email.toLowerCase()}`;
      const message = `${item.entity_type === 'report' ? 'Report' : 'Request'} ${item.id} is past its resolution deadline: ${item.title}`;
      if (preferences?.inapp_notifications !== false) {
        const { error } = await client.from('notifications').insert({
          user_email: admin.email,
          event_type: 'work_overdue',
          title: 'Overdue work item',
          message,
          entity_type: item.entity_type,
          entity_id: item.id,
          tracking_code: item.tracking_code,
          dedupe_key: `${dedupe}:inapp`
        });
        if (error && error.code !== '23505') throw error;
      }
      if (preferences?.email_notifications !== false) {
        const { data, error } = await client.from('notification_deliveries').upsert({
          channel: 'email',
          recipient: admin.email,
          subject: 'UNIFIX overdue work item',
          body: `${message}${item.tracking_code ? `\nTracking code: ${item.tracking_code}` : ''}`,
          event_type: 'work_overdue',
          entity_type: item.entity_type,
          entity_id: item.id,
          tracking_code: item.tracking_code,
          dedupe_key: `${dedupe}:email`
        }, { onConflict: 'dedupe_key', ignoreDuplicates: true }).select('id');
        if (error) throw error;
        for (const delivery of data || []) {
          queued += 1;
          await deliver(delivery.id);
        }
      }
      if (preferences?.sms_notifications && admin.phone) {
        const { data, error } = await client.from('notification_deliveries').upsert({
          channel: 'sms',
          recipient: admin.phone,
          body: `UNIFIX overdue: ${item.id} is past its resolution deadline.`,
          event_type: 'work_overdue',
          entity_type: item.entity_type,
          entity_id: item.id,
          tracking_code: item.tracking_code,
          dedupe_key: `${dedupe}:sms`
        }, { onConflict: 'dedupe_key', ignoreDuplicates: true }).select('id');
        if (error) throw error;
        for (const delivery of data || []) {
          queued += 1;
          await deliver(delivery.id);
        }
      }
    }
  }

  const { data: failed, error: failedError } = await client
    .from('notification_deliveries')
    .select('id')
    .eq('status', 'failed')
    .limit(50);
  if (failedError) throw failedError;
  for (const delivery of failed || []) await deliver(delivery.id);
  return queued;
}

Deno.serve(async (request) => {
  if (!authorized(request)) return new Response('Unauthorized', { status: 401 });
  if (request.method !== 'POST') return new Response('Method not allowed', { status: 405 });

  try {
    const body = await request.json();
    if (body?.action === 'overdue-sweep') {
      const queued = await queueOverdueNotifications();
      return Response.json({ queued });
    }
    const id = body?.record?.id ?? body?.id;
    if (typeof id !== 'string') return Response.json({ error: 'Delivery id is required.' }, { status: 400 });
    await deliver(id);
    return Response.json({ delivered: true });
  } catch (error) {
    console.error('Notification delivery failed.', error);
    return Response.json({ error: 'Notification delivery failed.' }, { status: 502 });
  }
});
