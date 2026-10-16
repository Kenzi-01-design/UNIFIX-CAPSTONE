const administratorNavigation = [
  {
    label: 'Main',
    items: [
      { view: 'dashboard', label: 'Dashboard', icon: 'dashboard', primary: true },
      { view: 'submit', label: 'Submit Report', icon: 'add' },
      { view: 'reports', label: 'Reports', icon: 'reports', badge: 'reports', primary: true },
      { view: 'requests', label: 'Requests', icon: 'requests', badge: 'requests', primary: true }
    ]
  },
  {
    label: 'Administration',
    items: [
      { view: 'admin', label: 'Admin Panel', icon: 'admin', primary: true },
      { view: 'activity-log', label: 'Activity Log', icon: 'activity' },
      { view: 'user-management', label: 'User Management', icon: 'users' },
      { view: 'evaluation-results', label: 'Evaluation Results', icon: 'activity' }
    ]
  },
  {
    label: 'Account',
    items: [
      { view: 'profile', label: 'Profile', icon: 'reporter' },
      { view: 'settings', label: 'Settings', icon: 'settings' }
    ]
  }
];

const roleNavigation = {
  Employee: [
    {
      label: 'Main',
      items: [
        { view: 'dashboard', label: 'Dashboard', icon: 'dashboard', primary: true },
        { view: 'submit-request', label: 'Submit Request', icon: 'request', primary: true },
        { view: 'my-requisitions', label: 'Requestitions', icon: 'requests', primary: true }
      ]
    },
    {
      label: 'Account',
      items: [
        { view: 'evaluation', label: 'System Evaluation', icon: 'success' },
        { view: 'profile', label: 'Profile', icon: 'reporter' },
        { view: 'settings', label: 'Settings', icon: 'settings' }
      ]
    }
  ],
  Personnel: [
    {
      label: 'Main',
      items: [
        { view: 'dashboard', label: 'Dashboard', icon: 'dashboard', primary: true },
        { view: 'reports', label: 'Reports', icon: 'reports', badge: 'reports', primary: true },
        { view: 'requests', label: 'Requests', icon: 'requests', badge: 'requests', primary: true },
        { view: 'tasks', label: 'Tasks', icon: 'tasks', primary: true }
      ]
    },
    {
      label: 'Account',
      items: [
        { view: 'profile', label: 'Profile', icon: 'reporter' },
        { view: 'settings', label: 'Settings', icon: 'settings' }
      ]
    }
  ],
  Admin: administratorNavigation,
  Assistant: administratorNavigation
};

export function getRoleNavigation(role, counts = {}) {
  return (roleNavigation[role] || roleNavigation.Admin).map((group) => ({
    ...group,
    items: group.items.map((item) => ({
      ...item,
      badgeCount: item.badge === 'reports'
        ? counts.reports || 0
        : item.badge === 'requests'
          ? counts.requests || 0
          : 0
    }))
  }));
}

export function getMobilePrimaryNavigation(role, counts = []) {
  return getRoleNavigation(role, counts)
    .flatMap((group) => group.items)
    .filter((item) => item.primary)
    .slice(0, 4);
}
