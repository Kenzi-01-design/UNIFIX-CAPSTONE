<template>
  <div id="report-modal" class="modal" :class="{ open: isOpen }" :aria-hidden="!isOpen">
    <div class="modal-overlay" @click="$emit('close')"></div>
    <div class="modal-content" v-if="report">
      <div class="modal-header">
        <div>
          <div class="modal-id">{{ report.id }}</div>
          <h3>{{ report.title }}</h3>
          <div class="modal-meta">{{ report.cat }} · {{ report.loc }}</div>
        </div>
        <button class="modal-close" @click="$emit('close')">✖</button>
      </div>

      <div class="modal-body">
        <div class="modal-row">
          <strong>Status:</strong>
          <span :class="['tag', report.status]">{{ formatStatus(report.status) }}</span>
        </div>
        <div class="modal-row">
          <strong>Risk Level:</strong>
          <span :class="['tag', report.risk]">{{ capitalize(report.risk) }}</span>
        </div>
        <div class="modal-row">
          <strong>Assigned Tech:</strong> 
          <span>{{ report.assignedTo || 'Unassigned' }}</span>
        </div>
        <div class="modal-row">
          <strong>Submitted By:</strong> 
          <span>{{ report.reporter || 'Unknown' }}</span>
        </div>
        <div class="modal-row">
          <strong>Date Reported:</strong> 
          <span>{{ report.date }}</span>
        </div>
        <div class="modal-row loc">
          <strong>Location:</strong> 
          <span>{{ report.loc }}</span>
        </div>
        <div class="modal-desc">{{ report.desc || report.description || 'No description provided.' }}</div>

        <!-- Attached Photo Inspection -->
        <div v-if="report.photo" class="modal-photo-section">
          <strong>Attached Photo:</strong>
          <div class="modal-photo-preview">
            <img :src="report.photo" :alt="report.title" />
          </div>
        </div>
      </div>

      <div class="modal-actions">
        <button class="btn-secondary" @click="$emit('close')">Close</button>

        <!-- Admin Specific Actions -->
        <template v-if="currentRole === 'Admin'">
          <button class="btn-primary" @click="$emit('assign', report.id)">
            {{ report.assignedTo ? 'Reassign' : 'Assign' }}
          </button>
          <button
            v-if="report.status !== 'resolved'"
            class="admin-action-btn resolve"
            @click="$emit('resolve', report.id)"
          >
            Mark Resolved
          </button>
        </template>

        <!-- Assigned Personnel Lifecycle Actions -->
        <template v-if="currentRole === 'Personnel' && isAssignedToCurrentUser">
          <button
            v-if="report.techState === 'assigned'"
            class="btn-primary"
            @click="$emit('tech-accept', report.id)"
          >
            Accept Job
          </button>
          <button
            v-if="report.techState === 'accepted'"
            class="btn-secondary"
            @click="$emit('tech-start', report.id)"
          >
            Start Work
          </button>
          <button
            v-if="['accepted', 'started'].includes(report.techState)"
            class="admin-action-btn resolve"
            @click="$emit('tech-complete', report.id)"
          >
            Mark Resolved
          </button>
          <span
            v-if="report.techState === 'completed'"
            style="font-weight: 700; color: var(--green); margin-left: auto;"
          >
            Job Completed ✅
          </span>
        </template>
      </div>
    </div>
  </div>
</template>

<script setup>
import { computed } from 'vue';

const props = defineProps({
  isOpen: {
    type: Boolean,
    default: false
  },
  report: {
    type: Object,
    default: null
  },
  currentRole: {
    type: String,
    default: 'Admin'
  },
  activeUserName: {
    type: String,
    default: ''
  }
});

const isAssignedToCurrentUser = computed(() => {
  if (!props.report) return false;
  const assigned = Array.isArray(props.report.assignedPersonnel)
    ? props.report.assignedPersonnel
    : (props.report.assignedTo || '').split(',').map((name) => name.trim());
  return assigned.includes(props.activeUserName);
});

defineEmits([
  'close',
  'assign',
  'resolve',
  'tech-accept',
  'tech-start',
  'tech-complete'
]);

function formatStatus(status) {
  if (!status) return '';
  return status === 'in-progress' ? 'In Progress' : capitalize(status);
}

function capitalize(str) {
  if (!str) return '';
  return str.charAt(0).toUpperCase() + str.slice(1);
}
</script>

<style scoped>
.modal-photo-section {
  margin-top: 14px;
}
.modal-photo-preview {
  margin-top: 8px;
  border-radius: 8px;
  overflow: hidden;
  max-height: 220px;
  border: 1px solid var(--border, #e2e8f0);
}
.modal-photo-preview img {
  width: 100%;
  height: 100%;
  object-fit: cover;
  display: block;
}
</style>
