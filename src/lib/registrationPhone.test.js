import { describe, expect, it } from 'vitest';
import { isValidRegistrationPhone, normalizeRegistrationPhone } from './registrationPhone.js';

describe('registration phone number', () => {
  it('keeps only digits and limits input to eleven digits', () => {
    expect(normalizeRegistrationPhone('(0917) 123-4567')).toBe('09171234567');
    expect(normalizeRegistrationPhone('09171234567890')).toBe('09171234567');
    expect(normalizeRegistrationPhone('+63 917 123 4567')).toBe('63917123456');
  });

  it('allows an empty optional number or exactly eleven digits', () => {
    expect(isValidRegistrationPhone('')).toBe(true);
    expect(isValidRegistrationPhone('09171234567')).toBe(true);
    expect(isValidRegistrationPhone('0917123456')).toBe(false);
    expect(isValidRegistrationPhone('0917123456a')).toBe(false);
  });
});
