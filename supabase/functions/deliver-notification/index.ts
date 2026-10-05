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
          'Idempotency-Key': `unifix-notification-${claimed.id}`,
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

async function retryFailedNotifications() {
  const { data: failed, error: failedError } = await client
    .from('notification_deliveries')
    .select('id')
    .eq('status', 'failed')
    .limit(50);
  if (failedError) throw failedError;
  for (const delivery of failed || []) await deliver(delivery.id);
  return failed?.length || 0;
}

Deno.serve(async (request) => {
  if (!authorized(request)) return new Response('Unauthorized', { status: 401 });
  if (request.method !== 'POST') return new Response('Method not allowed', { status: 405 });

  try {
    const body = await request.json();
    if (body?.action === 'retry-failed') {
      const retried = await retryFailedNotifications();
      return Response.json({ retried });
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
