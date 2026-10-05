const MAX_MESSAGE_LENGTH = 500

function errorMessage(error) {
  const message = error instanceof Error ? `${error.name}: ${error.message}` : String(error ?? 'Unknown client error')
  return message
    .replace(/[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/gi, '[email]')
    .replace(/https?:\/\/\S+/gi, '[url]')
    .replace(/\bBearer\s+\S+/gi, 'Bearer [redacted]')
    .slice(0, MAX_MESSAGE_LENGTH)
}

export function reportClientError(error, context = {}, env = import.meta.env) {
  const endpoint = env.VITE_ERROR_REPORT_URL
  if (!endpoint || typeof navigator === 'undefined') return

  let url
  try {
    url = new URL(endpoint)
  } catch {
    console.error('VITE_ERROR_REPORT_URL must be a valid HTTPS URL.')
    return
  }
  if (url.protocol !== 'https:') {
    console.error('VITE_ERROR_REPORT_URL must use HTTPS.')
    return
  }

  const payload = JSON.stringify({
    message: errorMessage(error),
    source: String(context.source || 'client').slice(0, 40),
    info: String(context.info || '').slice(0, 120),
    file: context.file ? String(context.file).split(/[\\/]/).pop().split('?')[0].slice(0, 120) : undefined,
    line: Number.isInteger(context.line) ? context.line : undefined,
    occurredAt: new Date().toISOString()
  })

  try {
    const request = navigator.sendBeacon?.(url, new Blob([payload], { type: 'application/json' }))
    if (!request) {
      void fetch(url, {
        method: 'POST',
        mode: 'cors',
        headers: { 'Content-Type': 'application/json' },
        body: payload,
        keepalive: true
      }).catch((reportingError) => {
        console.error('Could not send the client error report.', reportingError)
      })
    }
  } catch (reportingError) {
    console.error('Could not send the client error report.', reportingError)
  }
}
