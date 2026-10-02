<template>
  <div id="app">
    <!-- Toast Feedback Overlay -->
    <ToastContainer :toasts="toasts" />

    <!-- Public entry point -->
    <HomeView
      v-if="!isAuthenticated && publicPage === 'home'"
      @open-report="publicPage = 'report'"
      @open-login="publicPage = 'login'"
    />

    <SubmitReportView
      v-else-if="!isAuthenticated && publicPage === 'report'"
      public-mode
      captcha-required
      @back="publicPage = 'home'"
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
import { ref, computed, onMounted, onBeforeUnmount } from 'vue';

// Composables
import { useAuth } from './composables/useAuth.js';
import { useReports } from './composables/useReports.js';
import { useNotifications } from './composables/useNotifications.js';
import { useToast } from './composables/useToast.js';

// Components
import SideBar from './components/SideBar.vue';
import Topbar from './components/Topbar.vue';
import ReportModal from './components/ReportModal.vue';
import ToastContainer from './components/ToastContainer.vue';

// Views
import LoginView from './views/LoginView.vue';
import HomeView from './views/HomeView.vue';
import DashboardView from './views/DashboardView.vue';
import SubmitReportView from './views/SubmitReportView.vue';
import SubmitRequestView from './views/SubmitRequestView.vue';
import MyRequisitionsView from './views/MyRequisitionsView.vue';
import ActivityLogView from './views/ActivityLogView.vue';
import UserManagementView from './views/UserManagementView.vue';
import ReportView from './views/ReportView.vue';
import PersonnelTasksView from './views/PersonnelTasksView.vue';
import AdminView from './views/AdminView.vue';
import ProfileView from './views/ProfileView.vue';
import SettingsView from './views/SettingsView.vue';

const { currentRole, activeUserName, isAuthenticated, logout, loadSettings } = useAuth();
const { reports, resolveReport, techAccept, techStart, techComplete } = useReports();
const { notifications, refreshNotifications, markAllRead } = useNotifications();
const { toasts, showToast } = useToast();

const currentView = ref('dashboard');
const publicPage = ref('home');
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
  settings: 'System Settings'
};

const currentViewTitle = computed(() => viewTitles[currentView.value] || 'Dashboard');

const badgeCount = computed(() => {
  return reports.value.filter((r) => r.status === 'urgent' || r.status === 'pending').length;
});

const selectedReport = computed(() => {
  if (!selectedReportId.value) return null;
  return reports.value.find((r) => r.id.toLowerCase() === selectedReportId.value.toLowerCase()) || null;
});

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

function handleLoginSuccess(landingView) {
  currentView.value = currentRole.value === 'Employee' && landingView === 'submit'
    ? 'dashboard'
    : (landingView || 'dashboard');
  refreshNotifications(currentRole.value, activeUserName.value);
  resetInactivityTimer();
}

function handleLogout() {
  if (inactivityTimer) clearTimeout(inactivityTimer);
  logout();
  currentView.value = 'dashboard';
  publicPage.value = 'home';
  showToast('Signed out successfully.', 'info');
}

function handleReportSubmitted(newReport) {
  showToast(`Report ${newReport.id} logged. Tracking in reports list.`, 'info');
  navigateTo('reports');
}

function handlePublicReportSubmitted(newReport) {
  showToast(`Report ${newReport.id} has been submitted for review.`, 'success');
  publicPage.value = 'home';
}

function handleMarkAllRead() {
  markAllRead(currentRole.value, activeUserName.value);
  showToast('All notifications marked as read.', 'success');
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
  resolveReport(id);
  closeReportModal();
  showToast(`${id} marked resolved ✅`, 'success');
}

function handleModalTechAccept(id) {
  techAccept(id, activeUserName.value);
  closeReportModal();
  showToast(`${id} accepted.`, 'success');
}

function handleModalTechStart(id) {
  techStart(id, activeUserName.value);
  closeReportModal();
  showToast(`${id} marked In Progress.`, 'info');
}

function handleModalTechComplete(id) {
  techComplete(id, activeUserName.value);
  closeReportModal();
  showToast(`${id} marked resolved ✅`, 'success');
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
