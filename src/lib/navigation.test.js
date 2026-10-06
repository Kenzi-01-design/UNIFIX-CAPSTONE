import { describe, expect, it } from 'vitest';
import { canAccessView } from './access.js';
import { getMobilePrimaryNavigation, getRoleNavigation } from './navigation.js';

const roles = ['Employee', 'Assistant', 'Personnel', 'Admin'];

describe('role navigation', () => {
  it.each(roles)('%s navigation only includes views already permitted to the role', (role) => {
    const items = getRoleNavigation(role).flatMap((group) => group.items);
    expect(items.length).toBeGreaterThan(0);
    for (const item of items) expect(canAccessView(role, item.view)).toBe(true);
  });

  it.each(roles)('%s mobile shortcuts are drawn from the shared role menu', (role) => {
    const allViews = getRoleNavigation(role).flatMap((group) => group.items.map((item) => item.view));
    const primary = getMobilePrimaryNavigation(role);
    expect(primary.length).toBeLessThanOrEqual(4);
    expect(primary.length).toBeGreaterThan(0);
    for (const item of primary) expect(allViews).toContain(item.view);
  });

  it('carries report and request badges to desktop and mobile menu items', () => {
    const counts = { reports: 7, requests: 3 };
    const desktopItems = getRoleNavigation('Admin', counts).flatMap((group) => group.items);
    const mobileItems = getMobilePrimaryNavigation('Admin', counts);

    expect(desktopItems.find((item) => item.view === 'reports').badgeCount).toBe(7);
    expect(mobileItems.find((item) => item.view === 'reports').badgeCount).toBe(7);
    expect(mobileItems.find((item) => item.view === 'requests').badgeCount).toBe(3);
  });
});
