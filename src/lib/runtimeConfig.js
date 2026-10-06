export function isValidSupabaseUrl(value) {
  try {
    const url = new URL(String(value || '').trim())
    return ['http:', 'https:'].includes(url.protocol) && Boolean(url.hostname)
  } catch {
    return false
  }
}

export function getProductionConfigurationErrors(env = {}) {
  if (!env.PROD) return []

  const errors = []
  if (String(env.VITE_DEMO_MODE || '').trim().toLowerCase() === 'true') {
    errors.push('VITE_DEMO_MODE must not be enabled in a production build.')
  }

  const supabaseUrlValue = String(env.VITE_SUPABASE_URL || '').trim()
  const supabaseAnonKey = String(env.VITE_SUPABASE_ANON_KEY || '').trim()
  if (!supabaseUrlValue || !supabaseAnonKey) {
    errors.push('VITE_SUPABASE_URL and VITE_SUPABASE_ANON_KEY must be configured.')
  } else {
    try {
      const supabaseUrl = new URL(supabaseUrlValue)
      if (supabaseUrl.protocol !== 'https:' || !supabaseUrl.hostname) {
        errors.push('VITE_SUPABASE_URL must use HTTPS in production.')
      }
    } catch {
      errors.push('VITE_SUPABASE_URL must be a valid URL.')
    }
    if (!isValidSupabaseUrl(supabaseUrlValue) && !errors.includes('VITE_SUPABASE_URL must be a valid URL.')) {
      errors.push('VITE_SUPABASE_URL must be a valid URL.')
    }
  }

  if (!String(env.VITE_TURNSTILE_SITE_KEY || '').trim()) {
    errors.push('VITE_TURNSTILE_SITE_KEY must be configured for public report verification.')
  }

  return errors
}
