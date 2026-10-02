import { createClient } from '@supabase/supabase-js';

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL;
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY;

export const isSupabaseConfigured = Boolean(supabaseUrl && supabaseAnonKey);

export const supabase = isSupabaseConfigured
  ? createClient(supabaseUrl, supabaseAnonKey)
  : null;

/**
 * Sends an anonymous report through the server-side Turnstile check.
 * The Turnstile secret must never be exposed to the browser.
 */
export async function submitPublicReport(report, captchaToken) {
  if (!supabase) throw new Error('Supabase is not configured.');

  const { data, error } = await supabase.functions.invoke('submit-public-report', {
    body: { report, captchaToken }
  });

  if (error) throw error;
  if (!data?.report) throw new Error('The report service returned an invalid response.');
  return data.report;
}
