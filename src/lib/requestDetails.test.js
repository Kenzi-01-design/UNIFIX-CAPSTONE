import { describe, expect, it } from 'vitest';
import { formatRequestDetails } from './requestDetails.js';

describe('formatRequestDetails', () => {
  it('formats REAS details as labeled rows and columns', () => {
    expect(formatRequestDetails(
      'Item: 1.6 Outlets (Qty: 5). Defect: Pumotok. Preferred Date: 2026-11-03.'
    )).toEqual([
      { label: 'Item', value: '1.6 Outlets' },
      { label: 'Quantity', value: '5' },
      { label: 'Defect', value: 'Pumotok' },
      { label: 'Preferred date', value: '2026-11-03' }
    ]);
  });

  it('includes optional specifications and preferred date', () => {
    expect(formatRequestDetails(
      'Item: Air-con (Qty: 1). Defect: Not cooling. [Specs: Brand: ACME, Model: X2, Serial: 123] Preferred Date: 2026-11-04.'
    )).toEqual([
      { label: 'Item', value: 'Air-con' },
      { label: 'Quantity', value: '1' },
      { label: 'Defect', value: 'Not cooling' },
      { label: 'Brand', value: 'ACME' },
      { label: 'Model', value: 'X2' },
      { label: 'Serial number', value: '123' },
      { label: 'Preferred date', value: '2026-11-04' }
    ]);
  });

  it('preserves details from other request forms', () => {
    const details = '[ROUTINE] Leak under sink (Designation: Prof)';
    expect(formatRequestDetails(details)).toEqual([{ label: 'Details', value: details }]);
  });

  it('provides a fallback when details are empty', () => {
    expect(formatRequestDetails('')).toEqual([
      { label: 'Details', value: 'No additional details provided.' }
    ]);
  });
});
