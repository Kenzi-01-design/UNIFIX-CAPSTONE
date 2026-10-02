<template>
  <component :is="icon" :size="size" :stroke-width="strokeWidth" aria-hidden="true" />
</template>

<script setup>
import { computed } from 'vue';
import {
  Bell, BookOpen, BriefcaseBusiness, Building2, ChartNoAxesCombined, CheckCircle2, CircleAlert, CircleHelp,
  ClipboardList, Droplets, FileText, FolderKanban, Hammer, HardHat, House,
  Landmark, Lightbulb, LogOut, MapPin, Network, Package, Plus, ShieldCheck, Sparkles,
  UserRound, UsersRound, Wrench, Zap
} from '@lucide/vue';

const props = defineProps({
  name: { type: String, default: '' },
  size: { type: [Number, String], default: 18 },
  strokeWidth: { type: [Number, String], default: 2 }
});

const icons = {
  dashboard: House, home: House, report: ClipboardList, reports: ClipboardList,
  request: FileText, requests: FileText, tasks: HardHat, admin: ShieldCheck,
  users: UsersRound, settings: Wrench, notification: Bell, search: CircleHelp,
  location: MapPin, reporter: UserRound, add: Plus, export: FileText,
  print: FileText, building: Building2, electrical: Lightbulb, plumbing: Droplets,
  furniture: BriefcaseBusiness, hvac: Sparkles, network: Network, civil: Landmark,
  security: ShieldCheck, sanitation: Sparkles, other: Package, activity: FolderKanban,
  analytics: ChartNoAxesCombined, work: Hammer
  ,success: CheckCircle2, error: CircleAlert, info: CircleHelp, logout: LogOut, zap: Zap
};

const icon = computed(() => {
  const key = String(props.name).toLowerCase();
  return icons[key] || CircleHelp;
});
</script>
