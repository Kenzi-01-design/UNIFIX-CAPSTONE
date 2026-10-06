export function createRequestId() {
  const cryptoApi = globalThis.crypto;
  if (typeof cryptoApi?.randomUUID !== 'function') {
    throw new Error('Secure request ID generation is unavailable in this browser.');
  }
  return `#REQ-${cryptoApi.randomUUID()}`;
}
