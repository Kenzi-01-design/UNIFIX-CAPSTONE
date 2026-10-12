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
      'Alumni Bldg',
      'Administration Bldg',
      'College of Arts & Sciences Bldg',
      'Campus Quadrangle',
      'College of Teacher Education Bldg',
      'Boys Shop Building',
      'ROTC Building',
      'Rotary',
      'ROTC Bldg',
      'Mechanical Engineering Laboratory Bldg',
      'Engineering Science Lab Bldg',
      'Academic Classroom Bldg',
      'Engineering Bldg',
      'Stalls',
      'Graphic Arts & Bldg',
      'Technology Lab Bldg',
      'IT Lab Bldg',
      'RAC Bldg',
      'Auto Service Center',
      'Technician Institute',
      'CBA Bldg',
      'Cafeteria',
      'HRM Bldg',
      'Training Center'
    ]);
  });
});
