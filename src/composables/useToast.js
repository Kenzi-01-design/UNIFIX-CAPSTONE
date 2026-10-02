import { ref } from 'vue';

const toasts = ref([]);
let toastIdCounter = 0;

export function useToast() {
  function showToast(message, type = 'info', duration = 3500) {
    const id = ++toastIdCounter;
    const newToast = { id, message, type, isLeaving: false };
    toasts.value.push(newToast);

    setTimeout(() => {
      newToast.isLeaving = true;
      setTimeout(() => {
        toasts.value = toasts.value.filter((t) => t.id !== id);
      }, 300);
    }, duration);
  }

  return {
    toasts,
    showToast
  };
}