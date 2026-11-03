import { describe, expect, it } from 'vitest';
import { matchesFacilityLocation } from './facilityIssues.js';

describe('facility issue location matching', () => {
  const room = { building: 'Engineering', floor: 'Floor 1', room: 'Room 10' };

  it('matches the selected room, descendants, and room-only request locations', () => {
    expect(matchesFacilityLocation('Engineering · Floor 1 · Room 10', room)).toBe(true);
    expect(matchesFacilityLocation('Engineering · Floor 1 · Room 10 · North wall', room)).toBe(true);
    expect(matchesFacilityLocation('Engineering · Room 10 · Electrical panel', room)).toBe(true);
  });

  it('includes building-wide and floor-wide items but excludes sibling rooms and floors', () => {
    expect(matchesFacilityLocation('Engineering', room)).toBe(true);
    expect(matchesFacilityLocation('Engineering · Floor 1', room)).toBe(true);
    expect(matchesFacilityLocation('Engineering · Floor 1 · Room 11', room)).toBe(false);
    expect(matchesFacilityLocation('Engineering · Floor 2 · Room 10', room)).toBe(false);
  });

  it('matches all sublocations for a building-level facility link', () => {
    expect(matchesFacilityLocation('Engineering · Floor 2 · Room 10', { building: 'Engineering' })).toBe(true);
    expect(matchesFacilityLocation('Engineering Annex · Room 10', { building: 'Engineering' })).toBe(false);
  });
});
