from pathlib import Path

web_path=Path('web/index.html')
web=web_path.read_text(encoding='utf-8')
marker='bridgepoint-v441-mobile-install-fallback'
if marker in web:
    print('V441 mobile install fallback already applied.')
    raise SystemExit(0)

if 'bridgepoint-v439-gold-install-cta' not in web:
    raise SystemExit('V441 requires the V439 gold install CTA')
if 'bridgepoint-v310-install-onboarding' not in web:
    raise SystemExit('V441 requires the V310 install guide')

# Make the floating CTA a guaranteed touch target on narrow mobile browsers and ensure
# Flutter/canvas overlays cannot accidentally swallow the native HTML button tap.
style='''  <style id="bridgepoint-v441-mobile-install-fallback">
    #bp-install-fab-v439{pointer-events:auto!important;touch-action:manipulation;min-height:52px;-webkit-tap-highlight-color:rgba(0,0,0,0);isolation:isolate}
    #bp-install-fab-v439>*{pointer-events:none}
    #bp-install-fallback-v441{display:inline-flex;align-items:center;justify-content:center;min-height:46px;border-radius:12px;padding:12px 14px;text-decoration:none;font:900 12px/1.2 system-ui,-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;background:#122238;color:#fff;border:1px solid rgba(255,255,255,.16);flex:1 1 180px;touch-action:manipulation}
    #bp-install-fallback-v441:focus-visible,#bp-install-fab-v439:focus-visible{outline:3px solid rgba(255,226,91,.8);outline-offset:3px}
    @media(max-width:620px){#bp-install-fab-v439{left:10px;right:10px;bottom:calc(82px + env(safe-area-inset-bottom));max-width:none;width:auto;justify-content:flex-start;padding:10px 13px 10px 10px}#bp-install-fab-v439 strong{font-size:12px}#bp-install-fab-v439 small{font-size:10px}.bp-install-actions{display:grid!important;grid-template-columns:1fr!important}.bp-install-primary,.bp-install-secondary,#bp-install-fallback-v441{width:100%!important;min-width:0}}
  </style>
'''
if '</head>' not in web:
    raise SystemExit('V441 head anchor missing')
web=web.replace('</head>',style+'</head>',1)

# The old mobile guide hides its install primary whenever the browser does not supply a
# beforeinstallprompt event. Add an unconditional, ordinary HTTPS fallback into the action
# row so the user can always enter BridgePoint even when install capability is unavailable.
actions_anchor='''        <button id="bp-install-later" class="bp-install-secondary" type="button">Not now</button>'''
fallback='''        <a id="bp-install-fallback-v441" href="/app/?mode=signin&utm_source=install_guide&utm_medium=mobile_fallback&utm_campaign=open_app">Open BridgePoint now</a>\n        <button id="bp-install-later" class="bp-install-secondary" type="button">Not now</button>'''
if web.count(actions_anchor)!=1:
    raise SystemExit(f'V441 install actions anchor count {web.count(actions_anchor)}')
web=web.replace(actions_anchor,fallback,1)

old_runtime='''    const sync=()=>button.classList.toggle('show',!installed());
    button.addEventListener('click',()=>{if(installed()){sync();return;}if(typeof window.bridgePointShowInstallGuide==='function')window.bridgePointShowInstallGuide();else document.getElementById('bp-install-backdrop')?.classList.add('show');});'''
new_runtime='''    const appUrl='/app/?mode=signin&utm_source=gold_install_cta&utm_medium=floating_cta&utm_campaign=open_app';
    const setButtonCopy=(title,subtitle)=>{const strong=button.querySelector('strong');const small=button.querySelector('small');if(strong)strong.textContent=title;if(small)small.textContent=subtitle;button.setAttribute('aria-label',`${title}. ${subtitle}`)};
    const installPromptReady=()=>Boolean(window.bridgePointInstallPromptReadyV441);
    const sync=()=>{const isInstalled=installed();button.classList.toggle('show',!isInstalled);setButtonCopy(installPromptReady()?'INSTALL BRIDGEPOINT':'DOWNLOAD / OPEN APP',installPromptReady()?'Install BridgePoint on this device':'Open BridgePoint now or see install steps')};
    button.addEventListener('click',event=>{event.preventDefault();event.stopPropagation();if(installed()){window.location.assign(appUrl);return;}if(typeof window.bridgePointShowInstallGuide==='function'){window.bridgePointShowInstallGuide();return;}window.location.assign(appUrl);},{passive:false});'''
if web.count(old_runtime)!=1:
    raise SystemExit(f'V441 V439 runtime anchor count {web.count(old_runtime)}')
web=web.replace(old_runtime,new_runtime,1)

# Expose only a boolean capability signal from the existing V310 install prompt. No prompt
# object or auth/session data is exposed. The V439 CTA uses this strictly for accurate copy.
before_old="""    window.addEventListener('beforeinstallprompt',event=>{event.preventDefault();deferredPrompt=event;renderInstructions();setTimeout(showInstall,150)});"""
before_new="""    window.bridgePointInstallPromptReadyV441=false;
    window.addEventListener('beforeinstallprompt',event=>{event.preventDefault();deferredPrompt=event;window.bridgePointInstallPromptReadyV441=true;renderInstructions();setTimeout(showInstall,150);window.dispatchEvent(new Event('bridgepoint-install-capability-change'))});"""
if web.count(before_old)!=1:
    raise SystemExit(f'V441 V310 beforeinstallprompt anchor count {web.count(before_old)}')
web=web.replace(before_old,before_new,1)

# Keep floating-button copy synchronized if the capability arrives after Flutter boot.
closing="""    document.addEventListener('visibilitychange',()=>{if(!document.hidden)sync()});
    sync();"""
closing_new="""    document.addEventListener('visibilitychange',()=>{if(!document.hidden)sync()});
    window.addEventListener('bridgepoint-install-capability-change',sync);
    sync();"""
if web.count(closing)!=1:
    raise SystemExit(f'V441 V439 sync anchor count {web.count(closing)}')
web=web.replace(closing,closing_new,1)

# If a user taps the direct fallback, keep acquisition semantics truthful: this is an
# ordinary app-open action, never signup intent.
web=web.replace("</body>","  <script>document.getElementById('bp-install-fallback-v441')?.addEventListener('click',()=>{try{window.bridgepointTrack?.('VALUE_VIEW',{surface:'install_fallback',account_mode:'signin'})}catch(_){}});</script>\n</body>",1)

# Build-time invariants for the mobile repair.
checks=[
    'bridgepoint-v441-mobile-install-fallback',
    'id="bp-install-fallback-v441"',
    "window.location.assign(appUrl)",
    'pointer-events:auto!important',
    'touch-action:manipulation',
    'mode=signin&utm_source=install_guide',
]
missing=[item for item in checks if item not in web]
if missing:
    raise SystemExit(f'V441 invariant failure: {missing}')

web_path.write_text(web,encoding='utf-8')
print('Applied V441 mobile gold CTA fallback: guaranteed touch target + direct app-open fallback + truthful install capability copy.')
