import { describe, expect, it } from 'vitest'
import { getProductionConfigurationErrors } from './runtimeConfig.js'

const validProductionEnv = {
  PROD: true,
  VITE_SUPABASE_URL: 'https://example.supabase.co',
  VITE_SUPABASE_ANON_KEY: 'public-anon-key',
  VITE_TURNSTILE_SITE_KEY: 'public-site-key',
  VITE_DEMO_MODE: 'false'
}

describe('getProductionConfigurationErrors', () => {
  it('allows a fully configured production deployment', () => {
    expect(getProductionConfigurationErrors(validProductionEnv)).toEqual([])
  })

  it('does not prevent local development or demo builds from starting', () => {
    expect(getProductionConfigurationErrors({ VITE_DEMO_MODE: 'true' })).toEqual([])
  })

  it('rejects production demo mode', () => {
    expect(getProductionConfigurationErrors({
      ...validProductionEnv,
      VITE_DEMO_MODE: ' TRUE '
    })).toContain('VITE_DEMO_MODE must not be enabled in a production build.')
  })

  it('requires the Supabase and Turnstile public configuration', () => {
    expect(getProductionConfigurationErrors({ PROD: true })).toEqual(expect.arrayContaining([
      'VITE_SUPABASE_URL and VITE_SUPABASE_ANON_KEY must be configured.',
      'VITE_TURNSTILE_SITE_KEY must be configured for public report verification.'
    ]))
  })

  it('rejects an invalid or insecure Supabase URL', () => {
    expect(getProductionConfigurationErrors({
      ...validProductionEnv,
      VITE_SUPABASE_URL: 'not-a-url'
    })).toContain('VITE_SUPABASE_URL must be a valid URL.')

    expect(getProductionConfigurationErrors({
      ...validProductionEnv,
      VITE_SUPABASE_URL: 'http://example.supabase.co'
    })).toContain('VITE_SUPABASE_URL must use HTTPS in production.')
  })

  it('rejects blank environment values', () => {
    expect(getProductionConfigurationErrors({
      ...validProductionEnv,
      VITE_SUPABASE_ANON_KEY: '  ',
      VITE_TURNSTILE_SITE_KEY: ' '
    })).toEqual(expect.arrayContaining([
      'VITE_SUPABASE_URL and VITE_SUPABASE_ANON_KEY must be configured.',
      'VITE_TURNSTILE_SITE_KEY must be configured for public report verification.'
    ]))
  })
})
