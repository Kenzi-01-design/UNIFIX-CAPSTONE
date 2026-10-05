// @ts-nocheck
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const allowedOrigins = (Deno.env.get('PUBLIC_APP_ORIGINS') || Deno.env.get('PUBLIC_APP_ORIGIN') || '')
  .split(',')
  .map((origin) => origin.trim().replace(/\/$/, ''))
  .filter(Boolean);
const allowedHostnames = (Deno.env.get('TURNSTILE_ALLOWED_HOSTNAME') || '')
  .split(',')
  .map((hostname) => hostname.trim().toLowerCase())
  .filter(Boolean);
const requestBuckets = new Map<string, { count: number; resetAt: number }>();
const RATE_LIMIT = 10;
const RATE_WINDOW_MS = 60_000;
function getCorsHeaders(origin: string) {
  const headers: Record<string, string> = {
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Content-Type': 'application/json',
    Vary: 'Origin'
  };
  if (allowedOrigins.includes(origin)) headers['Access-Control-Allow-Origin'] = origin;
  return headers;
}

function isAllowedOrigin(origin: string) {
  return allowedOrigins.includes(origin);
}

function clientKey(request: Request) {
  return request.headers.get('cf-connecting-ip')
    || request.headers.get('x-forwarded-for')?.split(',')[0]?.trim()
    || 'unknown';
}

function isRateLimited(key: string) {
  const now = Date.now();
  const bucket = requestBuckets.get(key);
  if (!bucket || bucket.resetAt <= now) {
    requestBuckets.set(key, { count: 1, resetAt: now + RATE_WINDOW_MS });
    return false;
  }
  bucket.count += 1;
  return bucket.count > RATE_LIMIT;
}

const categories = new Set([
  'Electrical', 'Plumbing', 'Furniture', 'HVAC', 'Network', 'Civil', 'Security', 'Sanitation', 'Other'
]);
const MAX_PHOTOS = 3;
const MAX_PHOTO_BYTES = 5 * 1024 * 1024;
const photoTypes = new Set(['image/jpeg', 'image/png', 'image/webp']);

function response(body: Record<string, unknown>, status = 200, origin = '') {
  return new Response(JSON.stringify(body), { status, headers: getCorsHeaders(origin) });
}

function text(value: unknown, maxLength: number) {
  return typeof value === 'string' && value.trim().length > 0 && value.trim().length <= maxLength
    ? value.trim()
    : null;
}

function decodePhoto(value: unknown) {
  if (typeof value !== 'string' || value.length > Math.ceil(MAX_PHOTO_BYTES * 4 / 3) + 100) {
    throw new Error('Each photo must be 5 MB or smaller.');
  }
  const match = value.match(/^data:(image\/(?:jpeg|png|webp));base64,([A-Za-z0-9+/]+={0,2})$/);
  if (!match || !photoTypes.has(match[1])) throw new Error('Photos must be JPG, PNG, or WebP images.');

  const bytes = Uint8Array.from(atob(match[2]), (character) => character.charCodeAt(0));
  if (!bytes.length || bytes.length > MAX_PHOTO_BYTES) throw new Error('Each photo must be 5 MB or smaller.');
  const jpeg = bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff;
  const png = bytes.length >= 8 && bytes[0] === 0x89 && String.fromCharCode(...bytes.slice(1, 4)) === 'PNG';
  const webp = bytes.length >= 12
    && String.fromCharCode(...bytes.slice(0, 4)) === 'RIFF'
    && String.fromCharCode(...bytes.slice(8, 12)) === 'WEBP';
  const signatureMatches = (match[1] === 'image/jpeg' && jpeg)
    || (match[1] === 'image/png' && png)
    || (match[1] === 'image/webp' && webp);
  if (!signatureMatches) throw new Error('A photo does not match its declared image type.');
  return { bytes, contentType: match[1] };
}

Deno.serve(async (request) => {
  const origin = request.headers.get('origin') ?? '';
  if (!allowedOrigins.length) return new Response('Function is not configured.', { status: 500 });
  if (!isAllowedOrigin(origin)) return new Response('Forbidden origin.', { status: 403 });
  if (request.method === 'OPTIONS') return new Response('ok', { headers: getCorsHeaders(origin) });
  if (request.method !== 'POST') return response({ error: 'Method not allowed.' }, 405, origin);
  if (isRateLimited(clientKey(request))) {
    return new Response(JSON.stringify({ error: 'Too many reports submitted. Please try again later.' }), {
      status: 429,
      headers: { ...getCorsHeaders(origin), 'Retry-After': '60' }
    });
  }
  const contentLength = Number(request.headers.get('content-length') || 0);
  if (contentLength > 22 * 1024 * 1024) {
    return response({ error: 'The report and photos exceed the allowed upload size.' }, 413, origin);
  }

  try {
    const requestBody = await request.text();
    if (new TextEncoder().encode(requestBody).byteLength > 22 * 1024 * 1024) {
      return response({ error: 'The report and photos exceed the allowed upload size.' }, 413, origin);
    }
    let payload;
    try {
      payload = JSON.parse(requestBody);
    } catch {
      return response({ error: 'The request body must contain valid JSON.' }, 400, origin);
    }
    if (!payload || typeof payload !== 'object' || Array.isArray(payload)) {
      return response({ error: 'The request body must be a JSON object.' }, 400, origin);
    }
    const { report, captchaToken, photos = [] } = payload;
    if (!text(captchaToken, 4096)) return response({ error: 'Complete the security verification.' }, 400, origin);
    if (!Array.isArray(photos) || photos.length > MAX_PHOTOS) {
      return response({ error: `Attach no more than ${MAX_PHOTOS} photos.` }, 400, origin);
    }

    const title = text(report?.title, 160);
    const description = text(report?.desc, 4000);
    const category = text(report?.cat, 32);
    const location = text(report?.loc, 300);
    const reporterEmail = report?.reporterEmail == null || report.reporterEmail === ''
      ? null
      : text(report.reporterEmail, 254);
    if (!title || !description || !category || !categories.has(category) || !location) {
      return response({ error: 'The report contains invalid or missing fields.' }, 400, origin);
    }
    if (report?.reporterEmail && (!reporterEmail || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(reporterEmail))) {
      return response({ error: 'Enter a valid email address for status updates.' }, 400, origin);
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
    if (!result.success || (allowedHostnames.length && !allowedHostnames.includes(String(result.hostname || '').toLowerCase()))) {
      console.error('Turnstile verification failed', {
        hostname: result.hostname || null,
        errorCodes: result['error-codes'] || []
      });
      return response({
        error: 'Security verification failed. Check the Turnstile site key, secret, and allowed hostname.',
        codes: result['error-codes'] || []
      }, 403, origin);
    }

    let decodedPhotos;
    try {
      decodedPhotos = photos.map(decodePhoto);
    } catch (photoError) {
      return response({ error: photoError.message || 'The attached photos are invalid.' }, 400, origin);
    }
    const now = new Date();
    const id = `PUB-${crypto.randomUUID()}`;
    const admin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    );
    const uploadedPaths: string[] = [];
    const attachments = [];
    try {
      for (const photo of decodedPhotos) {
        const extension = photo.contentType === 'image/jpeg' ? 'jpg' : photo.contentType.slice('image/'.length);
        const path = `public/reports/${id}/before/${crypto.randomUUID()}.${extension}`;
        const { error: uploadError } = await admin.storage.from('report-photos').upload(
          path,
          photo.bytes,
          { contentType: photo.contentType, upsert: false }
        );
        if (uploadError) throw uploadError;
        uploadedPaths.push(path);
        attachments.push({ name: 'Public report photo', phase: 'before', path });
      }
    } catch (uploadError) {
      if (uploadedPaths.length) {
        const { error: cleanupError } = await admin.storage.from('report-photos').remove(uploadedPaths);
        if (cleanupError) console.error('Unable to remove partially uploaded report photos.', cleanupError);
      }
      console.error('Report photo upload failed', uploadError);
      return response({ error: 'Could not save the attached photos.' }, 500, origin);
    }

    const record = {
      id,
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
      reporter_email: reporterEmail,
      report_date: now.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' }),
      photo_attachments: attachments
    };

    const { data, error } = await admin.from('reports').insert(record).select().single();
    if (error) {
      if (uploadedPaths.length) {
        const { error: cleanupError } = await admin.storage.from('report-photos').remove(uploadedPaths);
        if (cleanupError) console.error('Unable to remove report photos after the database insert failed.', cleanupError);
      }
      console.error('Database insert failed', error);
      return response({ error: 'Could not save the report.' }, 500, origin);
    }

    return response({ report: {
      id: data.id, title: data.title, desc: data.description, cat: data.category,
      catIcon: data.category_icon, catBg: data.category_background, loc: data.location,
      risk: data.risk, status: data.status, assignedTo: '', techState: data.technician_state,
      reporter: data.reporter, date: data.report_date, photo: null,
      reporterEmail: data.reporter_email,
      trackingCode: data.tracking_code, priority: data.priority, dueAt: data.due_at,
      photoAttachments: data.photo_attachments || []
    } }, 200, origin);
  } catch (error) {
    console.error('Public report function error', error);
    return response({ error: 'Could not process the report.' }, 500, origin);
  }
});
