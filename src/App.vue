<template>
  <div id="app">
    <!-- Toast Feedback Overlay -->
    <ToastContainer :toasts="toasts" />

    <!-- Public entry point -->
    <HomeView
      v-if="!isAuthenticated && publicPage === 'home'"
      @open-report="publicPage = 'report'"
      @open-login="publicPage = 'login'"
      @open-register="publicPage = 'register'"
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
      v-else-if="publicPage === 'report' && (!isAuthenticated || Boolean(locationPrefillId))"
      public-mode
      :captcha-required="isSupabaseConfigured"
      :prefill-location-id="locationPrefillId"
      @back="publicPage = 'home'"
      @view-reports="navigateTo('reports')"
      @report-submitted="handlePublicReportSubmitted"
    />

    <RegisterView
      v-else-if="!isAuthenticated && publicPage === 'register'"
      @back="publicPage = 'home'"
      @open-login="publicPage = 'login'"
    />

    <LoginView
      v-else-if="!isAuthenticated"
      show-back
      @back="publicPage = 'home'"
      @register="publicPage = 'register'"
      @logged-in="handleLoginSuccess"
    />

    <!-- 2. Application Shell (Authenticated) -->
    <div v-else id="app-shell" class="active" :class="{ 'nav-drawer-open': navDrawerOpen }">
      <!-- Sidebar Navigation -->
      <SideBar
        ref="sidebarRef"
        :current-role="currentRole"
        :user-name="activeUserName"
        :current-view="currentView"
        :reports-badge-count="badgeCount"
        :requests-badge-count="requestBadgeCount"
        :drawer-open="navDrawerOpen"
        :drawer-mode="compactNavigation"
        @navigate="navigateTo"
        @logout="handleLogout"
        @close-drawer="closeNavigationDrawer"
      />
      <button
        v-if="navDrawerOpen"
        class="navigation-backdrop"
        type="button"
        aria-label="Close navigation"
        @click="closeNavigationDrawer"
      />

      <!-- Main Layout Frame -->
      <div class="main-content">
        <Topbar
          :title="currentViewTitle"
          :notifications="notifications"
          :loading="notificationsLoading"
          :drawer-open="navDrawerOpen"
          @trigger-search="navigateTo('reports')"
          @mark-all-read="handleMarkAllRead"
          @toggle-navigation="toggleNavigationDrawer"
        />

        <!-- Content Router -->
        <main class="page-content" tabindex="-1">
         <DashboardView
         v-if="currentView === 'dashboard'"
        :current-role="currentRole"
        @navigate="navigateTo"
        @open-report="openReportModalById"
        @filter-reports="openReportsWithFilter"
        @open-requests="openRequestsWithFilter"
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

          <RequestsView
            v-else-if="currentView === 'requests' && ['Admin', 'Personnel'].includes(currentRole)"
            :initial-status="activeRequestStatus"
            @open-request="openRequestModalById"
          />

          <PersonnelTasksView
            v-else-if="currentView === 'tasks'"
          />

          <AdminView
            v-else-if="currentView === 'admin' && ['Admin', 'Assistant'].includes(currentRole)"
            :current-role="currentRole"
            @open-report="openReportModalById"
            @open-request="openRequestModalById"
          />

          <ProfileView
            v-else-if="currentView === 'profile'"
          />

          <SettingsView
            v-else-if="currentView === 'settings'"
          />

          <EvaluationView
            v-else-if="currentView === 'evaluation' && currentRole === 'Employee'"
            respondent-role="Employee"
          />

          <EvaluationView
            v-else-if="currentView === 'evaluation-results' && currentRole === 'Admin'"
            admin-mode
          />
        </main>
      </div>
      <MobileNavigation
        :current-role="currentRole"
        :current-view="currentView"
        :reports-badge-count="badgeCount"
        :requests-badge-count="requestBadgeCount"
        :drawer-open="navDrawerOpen"
        @navigate="navigateTo"
        @open-drawer="openNavigationDrawer"
      />

      <!-- Report Details Modal Overlay -->
      <ReportModal
        :is-open="isModalOpen"
        :report="selectedReport"
        :current-role="currentRole"
        :active-user-name="activeUserName"
        @close="closeReportModal"
        @assign="handleModalAssign"
        @resolve="handleModalResolve"
        @reject="handleModalRejectReport"
        @tech-accept="handleModalTechAccept"
        @tech-start="handleModalTechStart"
        @tech-complete="handleModalTechComplete"
      />
      <RequestModal
        :is-open="isRequestModalOpen"
        :request="selectedRequest"
        :current-role="currentRole"
        @close="closeRequestModal"
        @verify="handleModalVerifyRequest"
        @reject="handleModalRejectRequest"
      />
    </div>
  </div>
</template>

<script setup>
import { ref, computed, watch, nextTick, onMounted, onBeforeUnmount, defineAsyncComponent } from 'vue';

// Composables
import { useAuth } from './composables/useAuth.js';
import { useReports } from './composables/useReports.js';
import { useRequests } from './composables/useRequests.js';
import { useNotifications } from './composables/useNotifications.js';
import { useToast } from './composables/useToast.js';
import { isSupabaseConfigured } from './lib/supabase.js';
import { canAccessView } from './lib/access.js';

// Components
import SideBar from './components/SideBar.vue';
import Topbar from './components/TopBar.vue';
import ReportModal from './components/ReportModal.vue';
import RequestModal from './components/RequestModal.vue';
import ToastContainer from './components/ToastContainer.vue';
import MobileNavigation from './components/MobileNavigation.vue';

// Views
import LoginView from './views/LoginView.vue';
import RegisterView from './views/RegisterView.vue';
import HomeView from './views/HomeView.vue';
import TrackReportView from './views/TrackReportView.vue';
import DashboardView from './views/DashboardView.vue';
import SubmitReportView from './views/SubmitReportView.vue';
import SubmitRequestView from './views/SubmitRequestView.vue';
import MyRequisitionsView from './views/MyRequisitionsView.vue';
import ActivityLogView from './views/ActivityLogView.vue';
import UserManagementView from './views/UserManagementView.vue';
import ReportView from './views/ReportView.vue';
import RequestsView from './views/RequestsView.vue';
import PersonnelTasksView from './views/PersonnelTasksView.vue';
import ProfileView from './views/ProfileView.vue';
import SettingsView from './views/SettingsView.vue';

const AdminView = defineAsyncComponent(() => import('./views/AdminView.vue'));
const EvaluationView = defineAsyncComponent(() => import('./views/EvaluationView.vue'));

const {
  currentRole, activeUserName, activeUserEmail, authNotice, passwordRecoveryMode,
  verifyNotificationEmail,
  isAuthenticated, logout, loadSettings
} = useAuth();
const {
  reports,
  loadReports,
  subscribeToReports,
  stopReportsSubscription,
  clearReportsForAccountChange,
  resolveReport,
  rejectReport,
  techAccept,
  techStart,
  techComplete
} = useReports();
const {
  requests,
  loadRequests,
  subscribeToRequests,
  stopRequestsSubscription,
  clearRequestsForAccountChange,
  acknowledgeRequest,
  rejectRequest
} = useRequests();
const {
  notifications,
  loading: notificationsLoading,
  refreshNotifications,
  markAllRead,
  stopNotifications
} = useNotifications();
const { toasts, showToast } = useToast();

const currentView = ref('dashboard');
const compactNavigation = ref(window.matchMedia('(max-width: 1023px)').matches);
const navDrawerOpen = ref(false);
const sidebarRef = ref(null);
let drawerReturnFocus = null;
let previousBodyOverflow = '';
const locationPrefillId = new URLSearchParams(window.location.search).get('location') || '';
const publicPage = ref(window.location.pathname.replace(/\/+$/, '') === '/report' ? 'report' : 'home');
const activeReportFilter = ref({});
const activeRequestStatus = ref('');
const isModalOpen = ref(false);
const selectedReportId = ref(null);
const isRequestModalOpen = ref(false);
const selectedRequestId = ref(null);

let inactivityTimer = null;

const viewTitles = {
  dashboard: 'Dashboard',
  submit: 'Submit Report',
  'submit-request': 'Submit Requisition',
  'my-requisitions': 'Requestitions',
  'activity-log': 'Activity & Request History',
  'user-management': 'User Management',
  reports: 'Reports Overview',
  requests: 'Requests Overview',
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

const requestBadgeCount = computed(() => {
  return requests.value.filter((request) => ['submitted', 'in-progress', 'for-verification'].includes(request.status)).length;
});

const selectedReport = computed(() => {
  if (!selectedReportId.value) return null;
  return reports.value.find((r) => r.id.toLowerCase() === selectedReportId.value.toLowerCase()) || null;
});

const selectedRequest = computed(() => {
  if (!selectedRequestId.value) return null;
  return requests.value.find((request) => request.id.toLowerCase() === selectedRequestId.value.toLowerCase()) || null;
});

async function refreshAuthenticatedData() {
  if (!isAuthenticated.value) return;
  const results = await Promise.allSettled([loadReports(), loadRequests()]);
  const failedLoads = results.filter((result) => result.status === 'rejected');
  if (failedLoads.length) {
    console.error('Some work items could not be loaded for the signed-in account.', failedLoads);
    showToast('Some work items could not be loaded. Please refresh or try again.', 'error');
  }
  subscribeToReports();
  subscribeToRequests();
  try {
    await refreshNotifications(currentRole.value, activeUserName.value);
  } catch (error) {
    console.error('Failed to load notifications.', error);
    showToast('Notifications could not be loaded.', 'error');
  }
}

let activeIdentity = '';
watch(authNotice, (message) => {
  if (message) publicPage.value = 'login';
});
watch(passwordRecoveryMode, (recovering) => {
  if (recovering) publicPage.value = 'login';
});
watch([isAuthenticated, currentRole, activeUserEmail], ([authenticated, role, email]) => {
  const nextIdentity = authenticated ? `${email.toLowerCase()}|${role}` : '';
  if (activeIdentity && activeIdentity !== nextIdentity) {
    stopReportsSubscription();
    stopRequestsSubscription();
    stopNotifications();
    clearReportsForAccountChange();
    clearRequestsForAccountChange();
  }
  activeIdentity = nextIdentity;
  if (!authenticated) {
    isModalOpen.value = false;
    selectedReportId.value = null;
    isRequestModalOpen.value = false;
    selectedRequestId.value = null;
    return;
  }
  if (!canAccessView(role, currentView.value)) {
    currentView.value = 'dashboard';
    activeReportFilter.value = {};
    isModalOpen.value = false;
    selectedReportId.value = null;
    isRequestModalOpen.value = false;
    selectedRequestId.value = null;
  }
  void refreshAuthenticatedData();
}, { immediate: true });

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
  document.addEventListener('keydown', handleNavigationKeydown);
  window.addEventListener('resize', closeDrawerOnDesktop);
  void completeNotificationEmailVerification();
});

onBeforeUnmount(() => {
  activityEvents.forEach((event) => window.removeEventListener(event, resetInactivityTimer));
  document.removeEventListener('keydown', handleNavigationKeydown);
  window.removeEventListener('resize', closeDrawerOnDesktop);
  if (navDrawerOpen.value) document.body.style.overflow = previousBodyOverflow;
  if (inactivityTimer) clearTimeout(inactivityTimer);
  stopReportsSubscription();
  stopRequestsSubscription();
  stopNotifications();
});

async function completeNotificationEmailVerification() {
  const url = new URL(window.location.href);
  const token = url.searchParams.get('verify-notification-email');
  if (!token) return;
  url.searchParams.delete('verify-notification-email');
  window.history.replaceState({}, '', url);
  try {
    const email = await verifyNotificationEmail(token);
    window.dispatchEvent(new CustomEvent('notification-email-verified', { detail: { email } }));
    showToast('Notification email verified. Email updates are still off until you enable and save them in Settings.', 'success');
  } catch (error) {
    console.error('Notification email verification failed.', error);
    showToast(error.message || 'This verification link is invalid or expired. Request a new one in Settings.', 'error');
  }
}

function navigateTo(view) {
  if (!canAccessView(currentRole.value, view)) {
    showToast('This page is not available for your account role.', 'info');
    return;
  }
  currentView.value = view;
  if (view !== 'reports') {
    activeReportFilter.value = {};
  }
  if (view !== 'requests') {
    activeRequestStatus.value = '';
  }
  const wasDrawerOpen = navDrawerOpen.value;
  closeNavigationDrawer(false);
  if (wasDrawerOpen) void nextTick(() => document.querySelector('.page-content')?.focus());
  resetInactivityTimer();
}

function toggleNavigationDrawer(event) {
  if (navDrawerOpen.value) {
    closeNavigationDrawer();
  } else {
    openNavigationDrawer(event);
  }
}

async function openNavigationDrawer(event) {
  if (window.matchMedia('(min-width: 1024px)').matches) return;
  if (!navDrawerOpen.value) {
    drawerReturnFocus = event?.currentTarget || document.activeElement;
    previousBodyOverflow = document.body.style.overflow;
    document.body.style.overflow = 'hidden';
    navDrawerOpen.value = true;
    await nextTick();
    sidebarRef.value?.$el.querySelector('.sidebar-close')?.focus();
  }
}

function closeNavigationDrawer(restoreFocus = true) {
  if (!navDrawerOpen.value) return;
  navDrawerOpen.value = false;
  document.body.style.overflow = previousBodyOverflow;
  if (restoreFocus) {
    const returnTarget = drawerReturnFocus;
    void nextTick(() => {
      if (returnTarget?.isConnected) returnTarget.focus();
    });
  }
}

function handleNavigationKeydown(event) {
  if (!navDrawerOpen.value) return;
  if (event.key === 'Escape') {
    event.preventDefault();
    closeNavigationDrawer();
    return;
  }
  if (event.key !== 'Tab') return;
  const drawer = sidebarRef.value?.$el;
  const focusable = [...(drawer?.querySelectorAll(
    'button:not([disabled]), a[href], input:not([disabled]), select:not([disabled]), textarea:not([disabled]), [tabindex]:not([tabindex="-1"])'
  ) || [])].filter((element) => element.getClientRects().length);
  if (!focusable.length) {
    event.preventDefault();
    drawer?.focus();
    return;
  }
  const first = focusable[0];
  const last = focusable[focusable.length - 1];
  if (!drawer.contains(document.activeElement)) {
    event.preventDefault();
    first.focus();
    return;
  }
  if (event.shiftKey && (document.activeElement === first || document.activeElement === drawer)) {
    event.preventDefault();
    last.focus();
  } else if (!event.shiftKey && document.activeElement === last) {
    event.preventDefault();
    first.focus();
  }
}

function closeDrawerOnDesktop() {
  compactNavigation.value = window.matchMedia('(max-width: 1023px)').matches;
  if (!compactNavigation.value) closeNavigationDrawer(false);
}

function openRequestsWithFilter(status = '') {
  if (!canAccessView(currentRole.value, 'requests')) {
    showToast('Requests are not available for your account role.', 'info');
    return;
  }
  activeRequestStatus.value = status;
  currentView.value = 'requests';
  resetInactivityTimer();
}

function openReportsWithFilter(filters = {}) {
  if (!canAccessView(currentRole.value, 'reports')) {
    showToast('Reports are not available for your account role.', 'info');
    return;
  }
  activeReportFilter.value = { ...filters };
  currentView.value = 'reports';
  resetInactivityTimer();
}

function handleLoginSuccess(landingView) {
  currentView.value = canAccessView(currentRole.value, landingView) ? landingView : 'dashboard';
  resetInactivityTimer();
}

async function handleLogout() {
  if (inactivityTimer) clearTimeout(inactivityTimer);
  closeNavigationDrawer(false);
  try {
    await logout();
    currentView.value = 'dashboard';
    publicPage.value = 'home';
    showToast('Signed out successfully.', 'info');
  } catch (error) {
    showToast(error.message || 'Unable to sign out. Please try again.', 'error');
  }
}

function handleReportSubmitted(newReport) {
  showToast(`Report ${newReport.trackingCode || newReport.id} logged. Keep this code to track its status.`, 'info');
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
  closeRequestModal();
  selectedReportId.value = reportId;
  isModalOpen.value = true;
}

function closeReportModal() {
  isModalOpen.value = false;
  selectedReportId.value = null;
}

function openRequestModalById(requestId) {
  closeReportModal();
  selectedRequestId.value = requestId;
  isRequestModalOpen.value = true;
}

function closeRequestModal() {
  isRequestModalOpen.value = false;
  selectedRequestId.value = null;
}

function handleModalAssign(reportId) {
  closeReportModal();
  navigateTo('admin');
}

async function handleModalResolve(id) {
  try {
    if (!await resolveReport(id)) {
      showToast('This report is no longer awaiting verification.', 'error');
      return;
    }
    closeReportModal();
    showToast(`${id} marked resolved ✅`, 'success');
  } catch (error) {
    console.error('Could not verify report.', error);
    showToast(error.message || 'Unable to verify this report.', 'error');
  }
}

async function handleModalRejectReport(id, reason) {
  try {
    if (!await rejectReport(id, reason)) {
      showToast('A rejection reason is required and the report must be awaiting verification.', 'error');
      return;
    }
    closeReportModal();
    showToast(`${id} returned to personnel for rework.`, 'success');
  } catch (error) {
    console.error('Could not return report for rework.', error);
    showToast(error.message || 'Unable to return this report for rework.', 'error');
  }
}

async function handleModalVerifyRequest(id) {
  try {
    if (!await acknowledgeRequest(id, 'Action taken by administration.')) {
      showToast('This request is no longer awaiting verification.', 'error');
      return;
    }
    closeRequestModal();
    showToast(`${id} verified and closed.`, 'success');
  } catch (error) {
    console.error('Could not verify request.', error);
    showToast(error.message || 'Unable to verify this request.', 'error');
  }
}

async function handleModalRejectRequest(id, reason) {
  try {
    if (!await rejectRequest(id, reason)) {
      showToast('A reason of 5–500 characters is required to request rework.', 'error');
      return;
    }
    closeRequestModal();
    showToast(`${id} returned to personnel for rework.`, 'success');
  } catch (error) {
    console.error('Could not return request for rework.', error);
    showToast(error.message || 'Unable to return this request for rework.', 'error');
  }
}

async function handleModalTechAccept(id) {
  try {
    const accepted = await techAccept(id, activeUserName.value);
    closeReportModal();
    showToast(accepted ? `${id} accepted.` : 'This report is no longer assigned to your account.', accepted ? 'success' : 'error');
  } catch (error) {
    console.error('Could not save report acceptance.', error);
    showToast(error.message || 'Unable to save acceptance. Check your connection and account permissions.', 'error');
  }
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
  min-height: 100dvh;
  background: var(--surface-2, #f8fafc);
}

.main-content {
  margin-left: var(--sidebar-w, 240px);
  flex: 1;
  display: flex;
  flex-direction: column;
  min-height: 100dvh;
}

.page-content {
  padding: 32px;
  flex: 1;
}

@media (max-width: 1023px) {
  .main-content {
    margin-left: 0;
  }
  .page-content {
    padding: clamp(16px, 3vw, 24px);
  }
}

@media (max-width: 600px) {
  .page-content {
    padding: 16px 14px calc(92px + env(safe-area-inset-bottom));
  }
}
</style>
