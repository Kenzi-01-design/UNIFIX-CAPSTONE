export function normalizeRegistrationPhone(value) {
  return String(value || '').replace(/\D/g, '').slice(0, 11);
}

export function isValidRegistrationPhone(value) {
  return value === '' || /^[0-9]{11}$/.test(value);
}
