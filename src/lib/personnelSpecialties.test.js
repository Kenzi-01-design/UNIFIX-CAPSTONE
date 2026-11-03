import { describe, expect, it } from 'vitest';
import { PERSONNEL_SPECIALTIES } from './personnelSpecialties.js';

describe('personnel specialties', () => {
  it('provides unique trades aligned with maintenance work categories', () => {
    expect(new Set(PERSONNEL_SPECIALTIES).size).toBe(PERSONNEL_SPECIALTIES.length);
    expect(PERSONNEL_SPECIALTIES).toEqual([
      'Electrical',
      'Plumbing',
      'Sewerage',
      'Furniture',
      'HVAC',
      'Network',
      'Civil',
      'Carpentry',
      'Security',
      'Sanitation',
      'Other'
    ]);
  });
});
