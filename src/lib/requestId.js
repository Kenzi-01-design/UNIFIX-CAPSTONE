function createWorkItemId(prefix) {
  const cryptoApi = globalThis.crypto;
  if (typeof cryptoApi?.randomUUID !== 'function') {
    throw new Error('Secure work item ID generation is unavailable in this browser.');
  }
  return `#${prefix}-${cryptoApi.randomUUID()}`;
}

export function createReportId() {
  return createWorkItemId('RPT');
}

export function createRequestId() {
  return createWorkItemId('REQ');
}
