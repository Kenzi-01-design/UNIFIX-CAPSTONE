import { describe, expect, it } from 'vitest';
import { demoBuildings } from './useLocations.js';

describe('campus building options', () => {
  it('matches the requested building list', () => {
    expect(demoBuildings).toEqual([
      'Oval',
      'Gymnasium',
      'Boys Dorm',
      'Ladies Dorm',
      'Motorpool',
      '5 Star CR',
      'Food Court',
      'Alumni Building',
      'Administration Building',
      'College of Arts & Sciences Building',
      'Campus Quadrangle',
      'College of Teacher Education Building',
      'Boys Shop Building',
      'ROTC Building',
      'Rotary',
      'ROTC Building',
      'Mechanical Engineering Laboratory Building',
      'Engineering Science Lab Building',
      'Academic Classroom Building',
      'Engineering Building',
      'Stalls',
      'Graphic Arts & Building',
      'Technology Lab Building',
      'IT Lab Building',
      'RAC Building',
      'Auto Service Center',
      'Technician Institute',
      'CBA Building',
      'Cafeteria',
      'HRM Building',
      'Training Center'
    ]);
  });
});
