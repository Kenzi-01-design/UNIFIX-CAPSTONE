export function formatRequestDetails(details) {
  const rawDetails = String(details || '').trim();
  if (!rawDetails) return [{ label: 'Details', value: 'No additional details provided.' }];

  const reasMatch = rawDetails.match(/^Item:\s*(.*?)\s+\(Qty:\s*([^)]+)\)\.\s*Defect:\s*([\s\S]*)$/i);
  if (!reasMatch) return [{ label: 'Details', value: rawDetails }];

  let remainder = reasMatch[3].trim();
  let preferredDate = '';
  let specifications = '';

  const preferredDateMatch = remainder.match(/\s*Preferred Date:\s*([\s\S]*?)\.?\s*$/i);
  if (preferredDateMatch) {
    preferredDate = preferredDateMatch[1].trim();
    remainder = remainder.slice(0, preferredDateMatch.index).trim();
  }

  const specificationsMatch = remainder.match(/\s*\[Specs:\s*([\s\S]*?)\]\s*$/i);
  if (specificationsMatch) {
    specifications = specificationsMatch[1].trim();
    remainder = remainder.slice(0, specificationsMatch.index).trim();
  }

  const rows = [
    { label: 'Item', value: reasMatch[1].trim() },
    { label: 'Quantity', value: reasMatch[2].trim() },
    { label: 'Defect', value: remainder.replace(/\.\s*$/, '').trim() }
  ];

  if (specifications) {
    const specificationLabels = [
      ['Brand', 'Brand'],
      ['Model', 'Model'],
      ['Serial', 'Serial number']
    ];
    for (const [key, label] of specificationLabels) {
      const match = specifications.match(new RegExp(`(?:^|,\\s*)${key}:\\s*([^,]*)`, 'i'));
      if (match) rows.push({ label, value: match[1].trim() });
    }
  }

  if (preferredDate) rows.push({ label: 'Preferred date', value: preferredDate });
  return rows;
}
