<template>
  <div id="app">
    <!-- Toast Feedback Overlay -->
    <ToastContainer :toasts="toasts" />

    <!-- Public entry point -->
    <HomeView
      v-if="!isAuthenticated && publicPage === 'home'"
      @open-report="publicPage = 'report'"
      @open-login="publicPage = 'login'"
      @open-track="publicPage = 'track'"
      @open-evaluation="publicPage = 'evaluation'"
    />

    <EvaluationView
      v-else-if="!isAuthenticated && publicPage === 'evaluation'"
      public-mode
      respondent-role="Public"
      @back="publicPage = 'home'"
    />

    <TrackReportView
      v-else-if="!isAuthenticated && publicPage === 'track'"
      @back="publicPage = 'home'"
    />

    <SubmitReportView
      v-else-if="!isAuthenticated && publicPage === 'report'"
      public-mode
      :captcha-required="isSupabaseConfigured"
      :prefill-location-id="locationPrefillId"
      @back="publicPage = 'home'"
      @view-reports="navigateTo('reports')"
      @report-submitted="handlePublicReportSubmitted"
    />

    <LoginView
      v-else-if="!isAuthenticated"
      show-back
      @back="publicPage = 'home'"
      @logged-in="handleLoginSuccess"
    />

    <!-- 2. Application Shell (Authenticated) -->
    <div v-else id="app-shell" class="active">
      <!-- Sidebar Navigation -->
      <SideBar
        :current-role="currentRole"
        :user-name="activeUserName"
        :current-view="currentView"
        :reports-badge-count="badgeCount"
        @navigate="navigateTo"
        @logout="handleLogout"
      />

      <!-- Main Layout Frame -->
      <div class="main-content">
        <Topbar
          :title="currentViewTitle"
          :notifications="notifications"
          :loading="notificationsLoading"
          @trigger-search="navigateTo('reports')"
          @mark-all-read="handleMarkAllRead"
        />

        <!-- Content Router -->
        <main class="page-content">
         <DashboardView
         v-if="currentView === 'dashboard'"
        :current-role="currentRole"
        @navigate="navigateTo"
        @open-report="openReportModalById"
        @filter-reports="openReportsWithFilter"
        />

          <SubmitReportView
            v-else-if="currentView === 'submit'"
            :prefill-location-id="locationPrefillId"
            @view-reports="navigateTo('reports')"
            @report-submitted="handleReportSubmitted"
          />

          <!-- Faculty: Submit Requisitions & Equipment Requests -->
          <SubmitRequestView
            v-else-if="currentView === 'submit-request'"
          />

          <MyRequisitionsView
            v-else-if="currentView === 'my-requisitions' && currentRole === 'Employee'"
          />

          <!-- Faculty: Consolidated Activity & Requisition Logs -->
          <ActivityLogView
            v-else-if="currentView === 'activity-log'"
          />

          <UserManagementView
            v-else-if="currentView === 'user-management' && currentRole === 'Admin'"
          />

          <ReportView
            v-else-if="currentView === 'reports'"
            :initial-filter="activeReportFilter"
            @open-report="openReportModalById"
          />

          <PersonnelTasksView
            v-else-if="currentView === 'tasks'"
          />

          <AdminView
            v-else-if="currentView === 'admin' && ['Admin', 'Assistant'].includes(currentRole)"
            :current-role="currentRole"
          />

          <ProfileView
            v-else-if="currentView === 'profile'"
          />

          <SettingsView
            v-else-if="currentView === 'settings'"
          />

          <EvaluationView
            v-else-if="currentView === 'evaluation'"
            :respondent-role="currentRole"
          />

          <EvaluationView
            v-else-if="currentView === 'evaluation-results' && currentRole === 'Admin'"
            admin-mode
          />
        </main>
      </div>

      <!-- Report Details Modal Overlay -->
      <ReportModal
        :is-open="isModalOpen"
        :report="selectedReport"
        :current-role="currentRole"
        :active-user-name="activeUserName"
        @close="closeReportModal"
        @assign="handleModalAssign"
        @resolve="handleModalResolve"
        @tech-accept="handleModalTechAccept"
        @tech-start="handleModalTechStart"
        @tech-complete="handleModalTechComplete"
      />
    </div>
  </div>
</template>

<script setup>
import { ref, computed, watch, onMounted, onBeforeUnmount, defineAsyncComponent } from 'vue';

// Composables
import { useAuth } from './composables/useAuth.js';
import { useReports } from './composables/useReports.js';
import { useRequests } from './composables/useRequests.js';
import { useNotifications } from './composables/useNotifications.js';
import { useToast } from './composables/useToast.js';
import { isSupabaseConfigured } from './lib/supabase.js';

// Components
import SideBar from './components/SideBar.vue';
import Topbar from './components/TopBar.vue';
import ReportModal from './components/ReportModal.vue';
import ToastContainer from './components/ToastContainer.vue';

// Views
import LoginView from './views/LoginView.vue';
import HomeView from './views/HomeView.vue';
import TrackReportView from './views/TrackReportView.vue';
import DashboardView from './views/DashboardView.vue';
import SubmitReportView from './views/SubmitReportView.vue';
import SubmitRequestView from './views/SubmitRequestView.vue';
import MyRequisitionsView from './views/MyRequisitionsView.vue';
import ActivityLogView from './views/ActivityLogView.vue';
import UserManagementView from './views/UserManagementView.vue';
import ReportView from './views/ReportView.vue';
import PersonnelTasksView from './views/PersonnelTasksView.vue';
import ProfileView from './views/ProfileView.vue';
import SettingsView from './views/SettingsView.vue';

const AdminView = defineAsyncComponent(() => import('./views/AdminView.vue'));
const EvaluationView = defineAsyncComponent(() => import('./views/EvaluationView.vue'));

const { currentRole, activeUserName, isAuthenticated, logout, loadSettings } = useAuth();
const { reports, loadReports, subscribeToReports, resolveReport, techAccept, techStart, techComplete } = useReports();
const { loadRequests, subscribeToRequests } = useRequests();
const {
  notifications,
  loading: notificationsLoading,
  refreshNotifications,
  markAllRead,
  stopNotifications
} = useNotifications();
const { toasts, showToast } = useToast();

const currentView = ref('dashboard');
const locationPrefillId = new URLSearchParams(window.location.search).get('location') || '';
const publicPage = ref(window.location.pathname.replace(/\/+$/, '') === '/report' ? 'report' : 'home');
const activeReportFilter = ref({});
const isModalOpen = ref(false);
const selectedReportId = ref(null);

let inactivityTimer = null;

const viewTitles = {
  dashboard: 'Dashboard',
  submit: 'Submit Report',
  'submit-request': 'Submit Requisition',
  'my-requisitions': 'Requestitions',
  'activity-log': 'Activity & Request History',
  'user-management': 'User Management',
  reports: 'Reports Overview',
  tasks: 'My Assigned Tasks',
  admin: 'Administration Panel',
  profile: 'Profile Overview',
  settings: 'System Settings',
  evaluation: 'System Evaluation',
  'evaluation-results': 'Evaluation Results'
};

const currentViewTitle = computed(() => viewTitles[currentView.value] || 'Dashboard');

const badgeCount = computed(() => {
  return reports.value.filter((r) => r.status === 'urgent' || r.status === 'pending').length;
});

const selectedReport = computed(() => {
  if (!selectedReportId.value) return null;
  return reports.value.find((r) => r.id.toLowerCase() === selectedReportId.value.toLowerCase()) || null;
});

async function refreshAuthenticatedData() {
  if (!isAuthenticated.value) return;
  await Promise.all([loadReports(), loadRequests()]);
  subscribeToReports();
  subscribeToRequests();
  try {
    await refreshNotifications(currentRole.value, activeUserName.value);
  } catch (error) {
    console.error('Failed to load notifications.', error);
    showToast('Notifications could not be loaded.', 'error');
  }
}

watch(isAuthenticated, refreshAuthenticatedData, { immediate: true });

// Auto-Logout Activity Tracker
function resetInactivityTimer() {
  if (inactivityTimer) clearTimeout(inactivityTimer);
  if (!isAuthenticated.value) return;

  const settings = loadSettings();
  const timeoutMins = parseInt(settings.timeout, 10);
  if (isNaN(timeoutMins) || timeoutMins <= 0) return;

  inactivityTimer = setTimeout(() => {
    handleLogout();
    showToast('Session expired due to inactivity.', 'info');
  }, timeoutMins * 60 * 1000);
}

const activityEvents = ['mousemove', 'mousedown', 'keydown', 'touchstart', 'scroll'];

onMounted(() => {
  activityEvents.forEach((event) => window.addEventListener(event, resetInactivityTimer, { passive: true }));
});

onBeforeUnmount(() => {
  activityEvents.forEach((event) => window.removeEventListener(event, resetInactivityTimer));
  if (inactivityTimer) clearTimeout(inactivityTimer);
  stopNotifications();
});

function navigateTo(view) {
  if (view === 'activity-log' && currentRole.value !== 'Admin') {
    showToast('Activity Log is available to administrators only.', 'info');
    return;
  }
  if (view === 'user-management' && currentRole.value !== 'Admin') {
    showToast('User Management is available to administrators only.', 'info');
    return;
  }
  if (view === 'evaluation-results' && currentRole.value !== 'Admin') {
    showToast('Evaluation Results are available to administrators only.', 'info');
    return;
  }
  if (view === 'submit' && currentRole.value === 'Employee') {
    showToast('Employees cannot submit maintenance reports.', 'info');
    return;
  }
  currentView.value = view;
  if (view !== 'reports') {
    activeReportFilter.value = {};
  }
  resetInactivityTimer();
}

function openReportsWithFilter(filters = {}) {
  activeReportFilter.value = { ...filters };
  currentView.value = 'reports';
  resetInactivityTimer();
}

async function handleLoginSuccess(landingView) {
  await refreshAuthenticatedData();
  currentView.value = currentRole.value === 'Employee' && landingView === 'submit'
    ? 'dashboard'
    : (landingView || 'dashboard');
  resetInactivityTimer();
}

function handleLogout() {
  if (inactivityTimer) clearTimeout(inactivityTimer);
  logout();
  stopNotifications();
  currentView.value = 'dashboard';
  publicPage.value = 'home';
  showToast('Signed out successfully.', 'info');
}

function handleReportSubmitted(newReport) {
  showToast(`Report ${newReport.id} logged. Keep tracking code ${newReport.trackingCode}.`, 'info');
}

function handlePublicReportSubmitted(newReport) {
  showToast(`Report submitted. Keep tracking code ${newReport.trackingCode}.`, 'success');
}

async function handleMarkAllRead() {
  try {
    await markAllRead(currentRole.value, activeUserName.value);
  } catch (error) {
    console.error('Could not mark notifications read.', error);
    showToast('Unable to update notifications. Please try again.', 'error');
  }
}

// Modal Handlers
function openReportModalById(reportId) {
  selectedReportId.value = reportId;
  isModalOpen.value = true;
}

function closeReportModal() {
  isModalOpen.value = false;
  selectedReportId.value = null;
}

function handleModalAssign(reportId) {
  closeReportModal();
  navigateTo('admin');
}

function handleModalResolve(id) {
  if (resolveReport(id)) {
    closeReportModal();
    showToast(`${id} marked resolved ✅`, 'success');
  } else {
    showToast('Assign personnel and wait for acceptance before resolving this report.', 'info');
  }
}

async function handleModalTechAccept(id) {
  const accepted = await techAccept(id, activeUserName.value);
  closeReportModal();
  showToast(accepted ? `${id} accepted.` : 'Unable to save acceptance. Check your Supabase access.', accepted ? 'success' : 'error');
}

async function handleModalTechStart(id) {
  const started = await techStart(id, activeUserName.value);
  closeReportModal();
  showToast(started ? `${id} marked In Progress.` : 'Unable to save the start status. Check your Supabase access.', started ? 'info' : 'error');
}

async function handleModalTechComplete(id) {
  const completed = await techComplete(id, activeUserName.value);
  closeReportModal();
  showToast(completed ? `${id} marked resolved ✅` : 'Unable to save completion. Check your Supabase access.', completed ? 'success' : 'error');
}
</script>

<style>
#app {
  min-height: 100vh;
  background: var(--surface-2, #f8fafc);
}

.main-content {
  margin-left: var(--sidebar-w, 240px);
  flex: 1;
  display: flex;
  flex-direction: column;
  min-height: 100vh;
}

.page-content {
  padding: 32px;
  flex: 1;
}

@media (max-width: 768px) {
  .main-content {
    margin-left: 0;
  }
  .page-content {
    padding: 16px;
  }
}
</style>
