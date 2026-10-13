const baseUrl = required('SMOKE_BASE_URL').replace(/\/$/, '')
const supabaseUrl = required('VITE_SUPABASE_URL').replace(/\/$/, '')
const anonKey = required('VITE_SUPABASE_ANON_KEY')
const checks = []
const failures = []

async function check(name, operation) {
  try {
    const result = await operation()
    checks.push(name)
    console.log(`PASS ${name}${typeof result === 'string' ? `: ${result}` : ''}`)
    return result
  } catch (error) {
    failures.push(name)
    console.error(`FAIL ${name}: ${error.message}`)
    return null
  }
}

async function request(url, options = {}) {
  const response = await fetch(url, { ...options, signal: AbortSignal.timeout(20_000) })
  const text = await response.text()
  let body
  try {
    body = text ? JSON.parse(text) : null
  } catch {
    body = text
  }
  return { response, body }
}

function required(name) {
  const value = process.env[name]
  if (!value) throw new Error(`Set ${name} before running the post-deploy smoke tests.`)
  return value
}

async function authenticate(role) {
  const expectedRole = role[0].toUpperCase() + role.slice(1)
  const email = required(`SMOKE_${role.toUpperCase()}_EMAIL`)
  const password = required(`SMOKE_${role.toUpperCase()}_PASSWORD`)
  const { response, body } = await request(`${supabaseUrl}/auth/v1/token?grant_type=password`, {
    method: 'POST',
    headers: { apikey: anonKey, 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password })
  })
  if (!response.ok || !body?.access_token || !body?.user?.id) {
    throw new Error(`${role} sign-in failed (${response.status}).`)
  }
  const profile = await request(
    `${supabaseUrl}/rest/v1/user_profiles?id=eq.${encodeURIComponent(body.user.id)}&select=role,is_active`,
    { headers: { apikey: anonKey, Authorization: `Bearer ${body.access_token}` } }
  )
  if (!profile.response.ok || profile.body?.[0]?.role !== expectedRole || !profile.body?.[0]?.is_active) {
    throw new Error(`${role} profile is missing, inactive, or has a different role.`)
  }
  return { accessToken: body.access_token, userId: body.user.id }
}

async function callFunction(name, payload, token = anonKey) {
  const { response, body } = await request(`${supabaseUrl}/functions/v1/${name}`, {
    method: 'POST',
    headers: {
      apikey: anonKey,
      Authorization: `Bearer ${token}`,
      Origin: baseUrl,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify(payload)
  })
  return { response, body }
}

await check('deployed homepage responds', async () => {
  const { response } = await request(baseUrl)
  if (!response.ok) throw new Error(`Homepage returned HTTP ${response.status}.`)
  return `HTTP ${response.status}`
})

await check('frontend health endpoint responds', async () => {
  const { response, body } = await request(`${baseUrl}/health.json`)
  if (!response.ok || body?.service !== 'unifix-frontend' || body?.status !== 'ok') {
    throw new Error('Health endpoint returned an unexpected response.')
  }
  return 'frontend hosting only'
})

const identities = {}
for (const role of ['employee', 'assistant', 'personnel', 'admin']) {
  const configured = process.env[`SMOKE_${role.toUpperCase()}_EMAIL`]
    && process.env[`SMOKE_${role.toUpperCase()}_PASSWORD`]
  if (!configured) {
    console.log(`SKIP ${role} login/profile: set SMOKE_${role.toUpperCase()}_EMAIL and password.`)
    continue
  }
  identities[role] = await check(`${role} login and active profile`, () => authenticate(role))
}

for (const role of ['assistant', 'personnel', 'admin']) {
  const identity = identities[role]
  if (!identity) continue
  await check(`${role} cannot submit an evaluation directly`, async () => {
    const { response } = await callFunction('swift-worker', {}, identity.accessToken)
    if (response.status !== 403) {
      throw new Error(`Expected HTTP 403, received ${response.status}.`)
    }
  })
}

if (process.env.SMOKE_TEST_WRITES === 'true') {
  const evaluation = {
    respondentRole: 'Public',
    submissionKey: crypto.randomUUID(),
    susAnswers: Array(10).fill(4),
    isoAnswers: {
      functionalSuitability: 4,
      performanceEfficiency: 4,
      compatibility: 4,
      usability: 4,
      reliability: 4,
      security: 4,
      maintainability: 4,
      portability: 4
    }
  }
  await check('public evaluation submission', async () => {
    const { response } = await callFunction('swift-worker', evaluation)
    if (!response.ok) throw new Error(`Public evaluation returned HTTP ${response.status}.`)
  })

  if (identities.employee) {
    await check('employee evaluation submission', async () => {
      const { response } = await callFunction('swift-worker', {
        ...evaluation,
        respondentRole: 'Employee',
        submissionKey: crypto.randomUUID()
      }, identities.employee.accessToken)
      if (!response.ok) throw new Error(`Employee evaluation returned HTTP ${response.status}.`)
    })
  }
} else {
  console.log('SKIP eligible evaluation submission: set SMOKE_TEST_WRITES=true (responses are stored anonymously).')
}

const admin = identities.admin
if (admin) {
  await check('maintenance schedule dry-run query is available', async () => {
    const today = new Intl.DateTimeFormat('en-CA', { timeZone: 'Asia/Manila' }).format(new Date())
    const { response } = await request(
      `${supabaseUrl}/rest/v1/maintenance_schedules?select=id&is_active=eq.true&next_due=lte.${today}`,
      {
        headers: {
          apikey: anonKey,
          Authorization: `Bearer ${admin.accessToken}`,
          Prefer: 'count=exact',
          Range: '0-0'
        }
      }
    )
    if (!response.ok) throw new Error(`Schedule query returned HTTP ${response.status}.`)
    return 'read-only due-schedule count; cron execution is not invoked'
  })
}

if (process.env.SMOKE_TEST_WRITES === 'true') {
  const captchaToken = required('SMOKE_TEST_CAPTCHA_TOKEN')
  const reporterEmail = process.env.SMOKE_TEST_REPORTER_EMAIL || ''
  const report = {
    title: `UNIFIX deployment smoke test ${new Date().toISOString()}`,
    desc: 'Automated post-deployment verification. Please close this test report.',
    cat: 'Other',
    loc: 'Deployment smoke test',
    reporterEmail
  }
  const submitted = await check('public report submission with live CAPTCHA token', async () => {
    const result = await callFunction('submit-public-report', { report, captchaToken })
    if (!result.response.ok || !result.body?.report?.trackingCode) {
      throw new Error(`Submission returned HTTP ${result.response.status}.`)
    }
    return result.body.report
  })

  if (submitted) {
    const trackingCode = submitted.trackingCode
    const reportId = submitted.id
    await check('tracking lookup for the submitted report', async () => {
      const { response, body } = await callFunction('track-report', {
        action: 'lookup',
        trackingCode
      })
      if (!response.ok || body?.workItem?.trackingCode !== trackingCode) {
        throw new Error(`Tracking lookup returned HTTP ${response.status}.`)
      }
    })

    if (admin && reportId) {
      await check('notification created for the smoke-test report', async () => {
        const notificationUrl = `${supabaseUrl}/rest/v1/notifications?select=id&entity_id=eq.${encodeURIComponent(reportId)}`
        const { response, body } = await request(notificationUrl, {
          headers: {
            apikey: anonKey,
            Authorization: `Bearer ${admin.accessToken}`
          }
        })
        if (!response.ok || !Array.isArray(body) || !body.length) {
          throw new Error(`No notification was visible to the admin account (HTTP ${response.status}).`)
        }
      })
    }
  }
} else {
  console.log('SKIP public report submission and tracking: set SMOKE_TEST_WRITES=true and provide a fresh CAPTCHA token.')
}

if (process.env.SMOKE_TEST_WRITES === 'true' && identities.employee) {
  await check('authenticated photo upload and cleanup', async () => {
    const path = `${identities.employee.userId}/reports/SMOKE-${crypto.randomUUID()}/before/${crypto.randomUUID()}.png`
    const png = Uint8Array.from(atob('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jz2sAAAAASUVORK5CYII='), (char) => char.charCodeAt(0))
    const url = `${supabaseUrl}/storage/v1/object/report-photos/${path}`
    const upload = await request(url, {
      method: 'POST',
      headers: {
        apikey: anonKey,
        Authorization: `Bearer ${identities.employee.accessToken}`,
        'Content-Type': 'image/png',
        'x-upsert': 'false'
      },
      body: png
    })
    if (!upload.response.ok) throw new Error(`Photo upload returned HTTP ${upload.response.status}.`)
    const deletion = await request(url, {
      method: 'DELETE',
      headers: {
        apikey: anonKey,
        Authorization: `Bearer ${identities.employee.accessToken}`
      }
    })
    if (!deletion.response.ok) throw new Error(`Uploaded test photo cleanup returned HTTP ${deletion.response.status}.`)
  })
} else if (identities.employee) {
  console.log('SKIP photo upload: set SMOKE_TEST_WRITES=true to upload and remove a temporary test photo.')
}

console.log('\nManual browser checks still required: restricted-route redirects, evaluation visibility by role, notification delivery, and scheduled-job execution.')
console.log(`${checks.length} passed; ${failures.length} failed.`)
if (failures.length) process.exitCode = 1
