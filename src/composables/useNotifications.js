import { ref } from 'vue';

const staticNotifications = [
  {
    text: 'Report #1042 has been assigned to maintenance.',
    time: '2 min ago',
    read: false
  },
  {
    text: 'Your report "Broken AC in Room 301" is now In Progress.',
    time: '1 hr ago',
    read: false
  },
  {
    text: 'Urgent: Flooding reported in Basement B2.',
    time: '3 hrs ago',
    read: false
  },
  {
    text: 'Report #1039 has been resolved. ✅',
    time: 'Yesterday',
    read: true
  }
];

const notifications = ref([]);

export function useNotifications() {
  function getTechNotifKey(techName) {
    const slug = (techName || '').toLowerCase().replace(/[^a-z0-9]+/g, '-');
    return `unifix-tech-notifs-${slug}`;
  }

  function loadTechNotifications(techName) {
    if (!techName) return [];
    try {
      const saved = localStorage.getItem(getTechNotifKey(techName));
      return saved ? JSON.parse(saved) : [];
    } catch (e) {
      console.warn('Failed loading tech notifications', e);
      return [];
    }
  }

  function saveTechNotifications(techName, notifs) {
    if (!techName) return;
    try {
      localStorage.setItem(
        getTechNotifKey(techName),
        JSON.stringify(notifs.slice(0, 30))
      );
    } catch (e) {
      console.warn('Failed saving tech notifications', e);
    }
  }

  function refreshNotifications(currentRole, activeUserName) {
    const techFeed =
      currentRole === 'Personnel' ? loadTechNotifications(activeUserName) : [];
    notifications.value = [...techFeed, ...staticNotifications];
  }

  function pushTechAssignmentNotification(techName, report, status) {
    const now = new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
    const statusLabel =
      status === 'in-progress'
        ? 'In Progress'
        : status.charAt(0).toUpperCase() + status.slice(1);

    const techNotifs = loadTechNotifications(techName);
    techNotifs.unshift({
      text: `${report.id} assigned to you: ${report.title} (${statusLabel})`,
      time: now,
      read: false
    });
    saveTechNotifications(techName, techNotifs);
  }

  function markAllRead(currentRole, activeUserName) {
    staticNotifications.forEach((item) => {
      item.read = true;
    });

    if (currentRole === 'Personnel') {
      const updatedTech = loadTechNotifications(activeUserName).map((item) => ({
        ...item,
        read: true
      }));
      saveTechNotifications(activeUserName, updatedTech);
    }

    refreshNotifications(currentRole, activeUserName);
  }

  return {
    notifications,
    refreshNotifications,
    pushTechAssignmentNotification,
    markAllRead
  };
}