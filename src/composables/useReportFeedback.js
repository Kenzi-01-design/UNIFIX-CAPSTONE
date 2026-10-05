import { ref } from 'vue';
import { isSupabaseConfigured, supabase, submitPublicReportFeedback } from '../lib/supabase.js';

const STORAGE_KEY = 'unifix-report-feedback-v1';
const feedback = ref([]);
const loading = ref(false);
const loadError = ref('');
let loaded = false;

function loadDemoFeedback() {
  try {
    feedback.value = JSON.parse(localStorage.getItem(STORAGE_KEY) || '[]');
  } catch (error) {
    console.warn('Failed loading demo report feedback.', error);
    feedback.value = [];
  }
}

export function useReportFeedback() {
  async function loadReportFeedback() {
    if (loaded || loading.value) return;
    loading.value = true;
    loadError.value = '';
    try {
      if (isSupabaseConfigured) {
        const { data, error } = await supabase
          .from('report_feedback')
          .select('report_id, reporter_email, rating, comment, created_at');
        if (error) throw error;
        feedback.value = data || [];
      } else {
        loadDemoFeedback();
      }
      loaded = true;
    } catch (error) {
      loadError.value = error.message || 'Unable to load report ratings.';
    } finally {
      loading.value = false;
    }
  }

  async function submitReportFeedback(report, rating, comment, trackingCode = '') {
    const numericRating = Number(rating);
    const safeComment = String(comment || '').trim();
    const publicLookup = isSupabaseConfigured && Boolean(trackingCode);
    if ((!report?.id && !publicLookup) || !Number.isInteger(numericRating) || numericRating < 1 || numericRating > 5) {
      throw new Error('Choose a rating from 1 to 5.');
    }
    if (safeComment.length > 500) throw new Error('Comments must be 500 characters or fewer.');
    if (!report?.id && !publicLookup) {
      throw new Error('The report could not be verified.');
    }
    if (report && !['closed', 'resolved'].includes(report.status)) {
      throw new Error('Feedback is available after the work is completed.');
    }
    if (report?.id && feedback.value.some((item) => item.report_id === report.id)) {
      throw new Error('Feedback has already been submitted for this report.');
    }

    if (publicLookup) {
      await submitPublicReportFeedback(trackingCode, numericRating, safeComment);
      if (report?.id) feedback.value.push({ report_id: report.id, rating: numericRating, comment: safeComment });
      return;
    }

    let reporterEmail = null;
    if (isSupabaseConfigured) {
      const { data: userData, error: userError } = await supabase.auth.getUser();
      if (userError) throw userError;
      reporterEmail = userData.user?.email;
      if (!reporterEmail) throw new Error('Sign in to submit feedback for your report.');
      const { data, error } = await supabase
        .from('report_feedback')
        .insert({
          report_id: report.id,
          reporter_email: reporterEmail,
          rating: numericRating,
          comment: safeComment
        })
        .select('report_id, reporter_email, rating, comment, created_at')
        .single();
      if (error) throw error;
      feedback.value.push(data);
    } else {
      const record = {
        report_id: report.id,
        reporter_email: reporterEmail,
        rating: numericRating,
        comment: safeComment,
        created_at: new Date().toISOString()
      };
      feedback.value.push(record);
      localStorage.setItem(STORAGE_KEY, JSON.stringify(feedback.value));
    }
    loaded = true;
  }

  function getFeedbackForReport(reportId) {
    return feedback.value.filter((item) => item.report_id === reportId);
  }

  function getAverageRating(reportId) {
    const rows = getFeedbackForReport(reportId);
    if (!rows.length) return null;
    return rows.reduce((sum, item) => sum + item.rating, 0) / rows.length;
  }

  function hasFeedbackForReport(reportId) {
    return feedback.value.some((item) => item.report_id === reportId);
  }

  return {
    feedback,
    loading,
    loadError,
    loadReportFeedback,
    submitReportFeedback,
    getFeedbackForReport,
    getAverageRating,
    hasFeedbackForReport
  };
}
