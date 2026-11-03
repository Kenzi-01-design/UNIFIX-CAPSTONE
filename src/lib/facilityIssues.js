function normalizeLocation(value) {
  return String(value || '').trim().toLowerCase();
}

function joinLocationParts(...parts) {
  return parts.map((part) => String(part || '').trim()).filter(Boolean).join(' · ').toLowerCase();
}

export function matchesFacilityLocation(value, facility) {
  const location = normalizeLocation(value);
  const building = joinLocationParts(facility?.building);
  if (!location || !building) return false;

  const floor = String(facility?.floor || '').trim();
  const room = String(facility?.room || '').trim();
  const fullPrefix = joinLocationParts(building, floor, room);
  const exactPrefixes = new Set([building]);
  if (floor) exactPrefixes.add(joinLocationParts(building, floor));
  if (room) exactPrefixes.add(fullPrefix);

  const roomOnlyPrefix = floor && room ? joinLocationParts(building, room) : '';
  if (roomOnlyPrefix) exactPrefixes.add(roomOnlyPrefix);

  if (exactPrefixes.has(location)) return true;
  return [fullPrefix, roomOnlyPrefix].some((prefix) => (
    prefix && location.startsWith(`${prefix} · `)
  ));
}
