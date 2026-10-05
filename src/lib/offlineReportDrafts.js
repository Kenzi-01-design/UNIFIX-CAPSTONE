const DATABASE_NAME = 'unifix-offline-v1';
const STORE_NAME = 'report-drafts';

function openDatabase() {
  return new Promise((resolve, reject) => {
    if (!('indexedDB' in globalThis)) {
      reject(new Error('Offline report drafts are not supported in this browser.'));
      return;
    }

    const request = indexedDB.open(DATABASE_NAME, 1);
    request.onupgradeneeded = () => {
      const database = request.result;
      if (!database.objectStoreNames.contains(STORE_NAME)) {
        database.createObjectStore(STORE_NAME, { keyPath: 'id' });
      }
    };
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error || new Error('Could not open offline draft storage.'));
  });
}

async function withDraftStore(mode, operation) {
  const database = await openDatabase();
  try {
    return await new Promise((resolve, reject) => {
      const transaction = database.transaction(STORE_NAME, mode);
      const request = operation(transaction.objectStore(STORE_NAME));
      let result;
      request.onsuccess = () => { result = request.result; };
      request.onerror = () => reject(request.error || new Error('Could not access offline report drafts.'));
      transaction.oncomplete = () => resolve(result);
      transaction.onerror = () => reject(transaction.error || new Error('Could not access offline report drafts.'));
      transaction.onabort = () => reject(transaction.error || new Error('Offline draft storage was interrupted.'));
    });
  } finally {
    database.close();
  }
}

export async function listOfflineReportDrafts() {
  const drafts = await withDraftStore('readonly', (store) => store.getAll());
  return drafts.sort((left, right) => right.createdAt - left.createdAt);
}

export async function saveOfflineReportDraft(draft) {
  const saved = {
    ...draft,
    id: draft.id || crypto.randomUUID(),
    createdAt: draft.createdAt || Date.now()
  };
  await withDraftStore('readwrite', (store) => store.put(saved));
  return saved;
}

export async function deleteOfflineReportDraft(id) {
  await withDraftStore('readwrite', (store) => store.delete(id));
}
