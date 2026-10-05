import { createClient } from '@supabase/supabase-js';

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL;
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY;

export const isDemoMode = import.meta.env.VITE_DEMO_MODE === 'true';
export const isSupabaseConfigured = Boolean(supabaseUrl && supabaseAnonKey) && !isDemoMode;

export const supabase = isSupabaseConfigured
  ? createClient(supabaseUrl, supabaseAnonKey)
  : null;

/**
 * Sends an anonymous report through the server-side Turnstile check.
 * The Turnstile secret must never be exposed to the browser.
 */
async function invokePublicFunction(name, body) {
  if (!supabase) throw new Error('Supabase is not configured.');

  const { data, error } = await supabase.functions.invoke(name, { body });

  if (error) {
    let message = error.message;
    if (error.context) {
      try {
        const body = await error.context.clone().json();
        if (body?.error) message = body.error;
      } catch {
        // Keep the original client error when the function response is not JSON.
      }
    }
    throw new Error(message);
  }
  return data;
}

export async function submitPublicReport(report, captchaToken, photos = []) {
  const data = await invokePublicFunction('submit-public-report', { report, captchaToken, photos });
  if (!data?.report) throw new Error('The report service returned an invalid response.');
  return data.report;
}

export async function lookupPublicReport(trackingCode) {
  const data = await invokePublicFunction('track-report', { action: 'lookup', trackingCode });
  if (!data?.workItem) throw new Error('The tracking service returned an invalid response.');
  return data.workItem;
}

export async function submitPublicReportFeedback(trackingCode, rating, comment) {
  const data = await invokePublicFunction('track-report', {
    action: 'feedback',
    trackingCode,
    rating,
    comment
  });
  if (!data?.submitted) throw new Error('The feedback service returned an invalid response.');
  return data;
}

export async function reopenPublicWorkItem(trackingCode, reason) {
  const data = await invokePublicFunction('track-report', {
    action: 'reopen',
    trackingCode,
    reason
  });
  if (!data?.submitted) throw new Error('The reopen service returned an invalid response.');
  return data;
}
