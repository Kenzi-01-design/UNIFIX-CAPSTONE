import { createApp } from 'vue'
import './style.css'
import App from './App.vue'
import { getProductionConfigurationErrors } from './lib/runtimeConfig.js'
import { reportClientError } from './lib/clientErrorReporting.js'

const configurationErrors = getProductionConfigurationErrors(import.meta.env)
const mountTarget = document.querySelector('#app')

window.addEventListener('vite:preloadError', (event) => {
  const reloadKey = 'unifix-preload-reload-at';
  const now = Date.now();

  try {
    const lastReload = Number(sessionStorage.getItem(reloadKey) || 0);
    if (now - lastReload < 30_000) return;
    sessionStorage.setItem(reloadKey, String(now));
  } catch (error) {
    console.warn('Could not check the stale-asset reload guard.', error);
    return;
  }

  event.preventDefault();
  window.location.reload();
});

if (!mountTarget) {
  throw new Error('Could not find the UNIFIX application mount point.')
}

if (configurationErrors.length) {
  const heading = document.createElement('h1')
  heading.textContent = 'UNIFIX is not configured for production'
  const message = document.createElement('p')
  message.textContent = 'Contact the deployment administrator to correct the production environment settings.'
  const details = document.createElement('ul')
  for (const configurationError of configurationErrors) {
    const item = document.createElement('li')
    item.textContent = configurationError
    details.append(item)
  }
  mountTarget.replaceChildren(heading, message, details)
} else {
  const app = createApp(App)
  app.config.errorHandler = (error, _instance, info) => {
    console.error(`UNIFIX Vue error (${info}).`, error)
    reportClientError(error, { source: 'vue', info })
  }
  app.mount(mountTarget)
}

window.addEventListener('error', (event) => {
  reportClientError(event.error || event.message, {
    source: 'window',
    file: event.filename,
    line: event.lineno
  })
})

window.addEventListener('unhandledrejection', (event) => {
  reportClientError(event.reason, { source: 'unhandledrejection' })
})

if (import.meta.env.PROD && configurationErrors.length === 0 && 'serviceWorker' in navigator) {
  window.addEventListener('load', () => {
    navigator.serviceWorker.register('/service-worker.js').catch((error) => {
      console.error('Could not register the UNIFIX offline service worker.', error);
    });
  });
}
