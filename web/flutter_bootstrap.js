{{flutter_js}}
{{flutter_build_config}}

(() => {
  const tracker = document.createElement('script');
  tracker.src = 'acquisition_tracker.js';
  tracker.async = true;
  tracker.dataset.bridgepointAcquisitionTracker = 'v421';
  document.head.appendChild(tracker);
})();

(() => {
  const MARKER = 'bridgepoint-pwa-update-handoff-v396';
  const STYLE_ID = 'bp-pwa-update-style-v396';
  const BANNER_ID = 'bp-pwa-update-v396';
  let reloading = false;
  let banner = null;

  function ensureStyle() {
    if (document.getElementById(STYLE_ID)) return;
    const style = document.createElement('style');
    style.id = STYLE_ID;
    style.textContent = `
      #${BANNER_ID}{
        position:fixed;left:50%;bottom:max(18px,env(safe-area-inset-bottom));transform:translate(-50%,24px);
        width:min(560px,calc(100vw - 24px));z-index:2147483646;display:flex;align-items:center;gap:12px;
        padding:12px 12px 12px 14px;border-radius:16px;border:1px solid rgba(53,210,232,.28);
        background:rgba(7,17,31,.96);color:#fff;box-shadow:0 18px 60px rgba(0,0,0,.45);
        font:600 13px/1.35 system-ui,-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;
        opacity:0;pointer-events:none;transition:opacity .22s ease,transform .22s ease;backdrop-filter:blur(16px)
      }
      #${BANNER_ID}.show{opacity:1;pointer-events:auto;transform:translate(-50%,0)}
      #${BANNER_ID} .bp-pwa-copy{min-width:0;flex:1}
      #${BANNER_ID} .bp-pwa-title{font-weight:850;font-size:13px;letter-spacing:.1px}
      #${BANNER_ID} .bp-pwa-sub{margin-top:2px;color:#9fb0c4;font-size:11px;font-weight:550}
      #${BANNER_ID} .bp-pwa-dot{width:9px;height:9px;border-radius:999px;flex:0 0 auto;background:#38d49a;box-shadow:0 0 14px rgba(56,212,154,.72)}
      #${BANNER_ID} button{min-height:42px;border:0;border-radius:11px;padding:0 14px;background:#35d2e8;color:#07111f;font:850 12px/1 system-ui,-apple-system,"Segoe UI",sans-serif;cursor:pointer;white-space:nowrap}
      #${BANNER_ID} button:disabled{opacity:.6;cursor:default}
      @media(max-width:520px){#${BANNER_ID}{align-items:flex-start;gap:10px;padding:12px}.bp-pwa-dot{margin-top:4px}#${BANNER_ID} button{min-height:44px;padding:0 12px}}
    `;
    document.head.appendChild(style);
  }

  function ensureBanner() {
    if (banner) return banner;
    ensureStyle();
    banner = document.createElement('div');
    banner.id = BANNER_ID;
    banner.setAttribute('role', 'status');
    banner.setAttribute('aria-live', 'polite');
    banner.dataset.bridgepointReleaseUx = MARKER;
    banner.innerHTML = `
      <span class="bp-pwa-dot" aria-hidden="true"></span>
      <div class="bp-pwa-copy">
        <div class="bp-pwa-title">BridgePoint update ready</div>
        <div class="bp-pwa-sub">A newer verified build is available. Refresh once to use it.</div>
      </div>
      <button type="button">Refresh</button>`;
    document.body.appendChild(banner);
    banner.querySelector('button').addEventListener('click', async () => {
      if (reloading) return;
      reloading = true;
      const button = banner.querySelector('button');
      button.disabled = true;
      button.textContent = 'Updating…';
      try {
        const registration = await navigator.serviceWorker?.getRegistration();
        const waiting = registration?.waiting;
        if (waiting) {
          waiting.postMessage({type: 'SKIP_WAITING'});
        } else if (registration) {
          await registration.update();
          registration.waiting?.postMessage({type: 'SKIP_WAITING'});
        }
      } catch (_) {
        // A refresh is still safe; the loader will reconcile the newest service worker.
      }
      window.setTimeout(() => window.location.reload(), 450);
    });
    return banner;
  }

  function showBanner() {
    const el = ensureBanner();
    requestAnimationFrame(() => el.classList.add('show'));
  }

  async function watchForUpdate() {
    if (!('serviceWorker' in navigator)) return;
    try {
      const registration = await navigator.serviceWorker.getRegistration();
      if (!registration) return;
      if (registration.waiting && navigator.serviceWorker.controller) showBanner();
      registration.addEventListener('updatefound', () => {
        const candidate = registration.installing;
        if (!candidate) return;
        candidate.addEventListener('statechange', () => {
          if (candidate.state === 'installed' && navigator.serviceWorker.controller) showBanner();
        });
      });
      document.addEventListener('visibilitychange', () => {
        if (document.visibilityState === 'visible') registration.update().catch(() => {});
      });
      window.setInterval(() => registration.update().catch(() => {}), 15 * 60 * 1000);
    } catch (_) {
      // Never block BridgePoint startup because service-worker update inspection failed.
    }
  }

  navigator.serviceWorker?.addEventListener('controllerchange', () => {
    if (!reloading) showBanner();
  });

  window.addEventListener('load', watchForUpdate, {once: true});
})();

_flutter.loader.load();
