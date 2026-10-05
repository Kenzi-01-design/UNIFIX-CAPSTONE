const COUNTER_PREFIX = 'unifix-tracking-counter-';
let memoryYear = new Date().getFullYear();
let memoryCounter = 0;

export function createDemoTrackingCode() {
  const year = new Date().getFullYear();
  let counter;

  try {
    const key = `${COUNTER_PREFIX}${year}`;
    counter = Number.parseInt(localStorage.getItem(key) || '0', 10) + 1;
    localStorage.setItem(key, String(counter));
  } catch (error) {
    console.warn('Could not persist the demo tracking counter; using an in-memory counter.', error);
    if (memoryYear !== year) {
      memoryYear = year;
      memoryCounter = 0;
    }
    counter = ++memoryCounter;
  }

  return `UNI-${year}-${String(counter).padStart(4, '0')}`;
}
