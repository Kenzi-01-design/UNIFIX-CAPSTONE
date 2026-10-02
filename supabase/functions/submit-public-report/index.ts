import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Content-Type': 'application/json'
};

const categories = new Set([
  'Electrical', 'Plumbing', 'Furniture', 'HVAC', 'Network', 'Civil', 'Security', 'Sanitation', 'Other'
]);

function response(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: corsHeaders });
}

function text(value: unknown, maxLength: number) {
  return typeof value === 'string' && value.trim().length > 0 && value.trim().length <= maxLength
    ? value.trim()
    : null;
}

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (request.method !== 'POST') return response({ error: 'Method not allowed.' }, 405);

  try {
    const { report, captchaToken } = await request.json();
    if (!text(captchaToken, 4096)) return response({ error: 'Complete the security verification.' }, 400);

    const title = text(report?.title, 160);
    const description = text(report?.desc, 4000);
    const category = text(report?.cat, 32);
    const location = text(report?.loc, 300);
    if (!title || !description || !category || !categories.has(category) || !location) {
      return response({ error: 'The report contains invalid or missing fields.' }, 400);
    }

    const verification = await fetch('https://challenges.cloudflare.com/turnstile/v0/siteverify', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        secret: Deno.env.get('TURNSTILE_SECRET_KEY') ?? '',
        response: captchaToken
      })
    });
    const result = await verification.json();
    if (!result.success) return response({ error: 'Security verification failed. Please try again.' }, 403);

    const now = new Date();
    const record = {
      id: `PUB-${crypto.randomUUID()}`,
      title,
      description,
      category,
      category_icon: text(report?.catIcon, 8),
      category_background: text(report?.catBg, 16),
      location,
      risk: 'low',
      status: 'pending',
      technician_state: 'unassigned',
      reporter: 'Public Reporter',
      report_date: now.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' })
    };

    const admin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    );
    const { data, error } = await admin.from('reports').insert(record).select().single();
    if (error) {
      console.error('Database insert failed', error);
      return response({ error: 'Could not save the report.' }, 500);
    }

    return response({ report: {
      id: data.id, title: data.title, desc: data.description, cat: data.category,
      catIcon: data.category_icon, catBg: data.category_background, loc: data.location,
      risk: data.risk, status: data.status, assignedTo: '', techState: data.technician_state,
      reporter: data.reporter, date: data.report_date, photo: null
    } });
  } catch (error) {
    console.error('Public report function error', error);
    return response({ error: 'Could not process the report.' }, 500);
  }
});
