import { ref } from 'vue';
import { isDemoMode, isSupabaseConfigured, supabase } from '../lib/supabase.js';
import { useReports } from './useReports.js';

const similarReports = ref([]);
const loading = ref(false);
const error = ref('');
const duplicateNotes = ref([]);
const notesLoading = ref(false);
const notesError = ref('');
let searchSequence = 0;
let notesSequence = 0;

function clearSimilarReports() {
  searchSequence += 1;
  similarReports.value = [];
  loading.value = false;
  error.value = '';
}

function normalize(value) {
  return String(value || '').toLowerCase().replace(/[^a-z0-9 ]/g, ' ').replace(/\s+/g, ' ').trim();
}

function diceSimilarity(left, right) {
  const a = normalize(left);
  const b = normalize(right);
  if (!a || !b) return 0;
  if (a === b) return 1;
  const bigrams = (value) => {
    const tokens = value.split(' ');
    const pairs = new Set();
    tokens.forEach((token) => {
      for (let index = 0; index < token.length - 1; index += 1) pairs.add(token.slice(index, index + 2));
    });
    return pairs;
  };
  const first = bigrams(a);
  const second = bigrams(b);
  if (!first.size || !second.size) return 0;
  let shared = 0;
  first.forEach((pair) => { if (second.has(pair)) shared += 1; });
  return (2 * shared) / (first.size + second.size);
}

function getAnonymousVoteId() {
  const key = 'unifix-anonymous-voter-v1';
  try {
    let value = localStorage.getItem(key);
    if (!value) {
      value = crypto.randomUUID();
      localStorage.setItem(key, value);
    }
    return value;
  } catch (caught) {
    console.error('Could not persist anonymous duplicate-vote identity.', caught);
    throw new Error('Anonymous voting needs browser storage. Enable local storage and try again.');
  }
}

async function getAnonymousIdForRpc() {
  if (!isSupabaseConfigured || isDemoMode) return getAnonymousVoteId();
  const { data, error: sessionError } = await supabase.auth.getSession();
  if (sessionError) throw sessionError;
  return data.session ? null : getAnonymousVoteId();
}

async function findSimilarOpenReports({ category, location, title }) {
  const sequence = ++searchSequence;
  similarReports.value = [];
  error.value = '';
  const cleanTitle = String(title || '').trim();
  if (!category || !location || cleanTitle.length < 3) return [];
  loading.value = true;
  try {
    let results;
    if (isSupabaseConfigured && !isDemoMode) {
        const anonymousId = await getAnonymousIdForRpc();
        const { data, error: rpcError } = await supabase.rpc('find_similar_open_reports', {
        p_category: category,
        p_location: location,
        p_title: cleanTitle,
        p_anonymous_id: anonymousId
      });
      if (rpcError) throw rpcError;
      results = (data || []).map((row) => ({
        id: row.id,
        title: row.title,
        loc: row.location,
        status: row.status,
        similarity: Number(row.similarity) || 0
      }));
    } else {
      const { reports } = useReports();
      results = reports.value
        .filter((report) => report.status !== 'closed' && report.status !== 'resolved'
          && normalize(report.cat) === normalize(category)
          && normalize(report.loc) === normalize(location))
        .map((report) => ({
          id: report.id,
          title: report.title,
          loc: report.loc,
          status: report.status,
          similarity: diceSimilarity(cleanTitle, report.title)
        }))
        .filter((report) => report.similarity >= 0.2)
        .sort((a, b) => b.similarity - a.similarity)
        .slice(0, 5);
    }
    if (sequence === searchSequence) similarReports.value = results;
    return results;
  } catch (caught) {
    if (sequence === searchSequence) {
      error.value = caught.message || 'Similar reports could not be checked.';
      console.error('Failed to check for similar open reports.', caught);
    }
    throw caught;
  } finally {
    if (sequence === searchSequence) loading.value = false;
  }
}

async function voteForDuplicate(reportId, note = '') {
  const safeNote = String(note || '').trim();
  if (safeNote.length > 500) throw new Error('The note must be 500 characters or fewer.');
  if (isSupabaseConfigured && !isDemoMode) {
    const anonymousId = await getAnonymousIdForRpc();
    const { error: rpcError } = await supabase.rpc('add_report_duplicate_vote', {
      p_report_id: reportId,
      p_note: safeNote,
      p_anonymous_id: anonymousId
    });
    if (rpcError) throw rpcError;
    return;
  }

  const key = 'unifix-duplicate-votes-v1';
  try {
    const votes = JSON.parse(localStorage.getItem(key) || '[]');
    const voterId = getAnonymousVoteId();
    const existing = votes.find((vote) => vote.reportId === reportId && vote.voterId === voterId);
    if (existing) {
      existing.note = safeNote;
      existing.updatedAt = new Date().toISOString();
    } else {
      votes.push({ reportId, voterId, note: safeNote, createdAt: new Date().toISOString() });
    }
    localStorage.setItem(key, JSON.stringify(votes));
  } catch (caught) {
    console.error('Could not save the duplicate report vote.', caught);
    throw new Error(caught.message || 'The vote could not be saved in this browser.');
  }
}

async function loadDuplicateNotes(reportId) {
  const sequence = ++notesSequence;
  duplicateNotes.value = [];
  notesError.value = '';
  if (!reportId) {
    notesLoading.value = false;
    return;
  }
  notesLoading.value = true;
  try {
    if (isSupabaseConfigured && !isDemoMode) {
      const { data, error: rpcError } = await supabase.rpc('get_report_duplicate_notes', {
        p_report_id: reportId
      });
      if (rpcError) throw rpcError;
      if (sequence === notesSequence) duplicateNotes.value = data || [];
      return;
    }
    const votes = JSON.parse(localStorage.getItem('unifix-duplicate-votes-v1') || '[]');
    const results = votes.filter((vote) => vote.reportId === reportId)
      .map((vote) => ({
        note: vote.note || 'Reporter confirmed this is the same issue.',
        created_at: vote.updatedAt || vote.createdAt
      }))
      .sort((a, b) => String(b.created_at).localeCompare(String(a.created_at)));
    if (sequence === notesSequence) duplicateNotes.value = results;
  } catch (caught) {
    if (sequence === notesSequence) {
      notesError.value = caught.message || 'Duplicate notes could not be loaded.';
      console.error('Failed to load duplicate-report notes.', caught);
    }
    throw caught;
  } finally {
    if (sequence === notesSequence) notesLoading.value = false;
  }
}

export function useDuplicateReports() {
  return {
    similarReports,
    loading,
    error,
    duplicateNotes,
    notesLoading,
    notesError,
    findSimilarOpenReports,
    clearSimilarReports,
    voteForDuplicate,
    loadDuplicateNotes
  };
}
