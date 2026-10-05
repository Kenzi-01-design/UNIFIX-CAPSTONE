const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

function hasText(value, maxLength) {
  return typeof value === 'string' && value.trim().length > 0 && value.length <= maxLength;
}

export function validateReportInput(report) {
  if (!hasText(report?.title, 160)
    || !hasText(report?.desc, 4000)
    || !hasText(report?.cat, 80)
    || !hasText(report?.loc, 300)
    || !hasText(report?.reporter, 120)) {
    throw new Error('The report contains missing or oversized fields.');
  }
  const email = String(report?.reporterEmail || '').trim();
  if (email && (email.length > 254 || !EMAIL_PATTERN.test(email))) {
    throw new Error('Enter a valid email address for report updates.');
  }
}

export function validateRequestInput(request) {
  if (!hasText(request?.title, 160)
    || !hasText(request?.cat, 80)
    || !hasText(request?.dept, 300)
    || !hasText(request?.details, 4000)
    || !hasText(request?.requester, 120)) {
    throw new Error('The request contains missing or oversized fields.');
  }
  const email = String(request?.requesterEmail || '').trim();
  if (email && (email.length > 254 || !EMAIL_PATTERN.test(email))) {
    throw new Error('Enter a valid email address for request updates.');
  }
}
