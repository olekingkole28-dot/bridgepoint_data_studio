import os
from pathlib import Path


web_path = Path(os.environ.get("BRIDGEPOINT_WEB_INDEX", "web/index.html"))
web = web_path.read_text(encoding="utf-8")
marker = "bridgepoint-v443-install-guide-runtime"

if marker in web:
    print("V443 install-guide runtime repair already applied.")
    raise SystemExit(0)

required = [
    "bridgepoint-v310-install-onboarding",
    "bridgepoint-v441-mobile-install-fallback",
    "bridgepoint-v442-install-guide-mobile-width",
    'id="bp-install-backdrop"',
    'id="bp-install-fallback-v441"',
]
missing = [item for item in required if item not in web]
if missing:
    raise SystemExit(f"V443 prerequisites missing: {missing}")

old_fallback = '<a id="bp-install-fallback-v441" href="/app/?mode=signin&utm_source=install_guide&utm_medium=mobile_fallback&utm_campaign=open_app">Open BridgePoint now</a>'
new_fallback = '<button id="bp-install-fallback-v441" class="bp-install-secondary" type="button">Continue to BridgePoint</button>'
if web.count(old_fallback) != 1:
    raise SystemExit(f"V443 fallback anchor count {web.count(old_fallback)}")
web = web.replace(old_fallback, new_fallback, 1)

old_note = 'If you choose “Not now,” BridgePoint will remind you on a future browser sign-in until this device has been installed.'
new_note = 'Continue into BridgePoint now. You can install it later from the gold app button.'
if web.count(old_note) != 1:
    raise SystemExit(f"V443 install note count {web.count(old_note)}")
web = web.replace(old_note, new_note, 1)

old_show = """    function showInstall(){
      if(shown||alreadyInstalled()||dismissedThisSession())return;
"""
new_show = """    function showInstall(force=false){
      if(shown||alreadyInstalled()||dismissedThisSession()||(!force&&!hasAuthSession()))return;
"""
if web.count(old_show) != 1:
    raise SystemExit(f"V443 showInstall contract count {web.count(old_show)}")
web = web.replace(old_show, new_show, 1)

old_manual = "window.bridgePointShowInstallGuide=()=>{try{sessionStorage.removeItem(dismissedKey)}catch(_){ }shown=false;showInstall()};"
new_manual = "window.bridgePointShowInstallGuide=()=>{try{sessionStorage.removeItem(dismissedKey)}catch(_){ }shown=false;showInstall(true)};"
if web.count(old_manual) != 1:
    raise SystemExit(f"V443 manual install-guide contract count {web.count(old_manual)}")
web = web.replace(old_manual, new_manual, 1)

style = '''  <style id="bridgepoint-v443-install-guide-runtime">
    #bp-install-backdrop{display:none;position:fixed;inset:0;z-index:2147483647;background:rgba(2,8,16,.82);backdrop-filter:blur(12px);padding:18px;align-items:center;justify-content:center;font-family:system-ui,-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;box-sizing:border-box;overscroll-behavior:contain}
    #bp-install-backdrop.show{display:flex}
    #bp-install-backdrop:not(.show){visibility:hidden;pointer-events:none}
    #bp-install-card{width:min(520px,100%);max-width:100%;max-height:min(760px,calc(100vh - 28px));overflow:auto;overscroll-behavior:contain;border-radius:24px;border:1px solid rgba(53,210,232,.28);background:linear-gradient(155deg,rgba(13,26,43,.99),rgba(7,17,31,.995));box-shadow:0 30px 100px rgba(0,0,0,.62);color:#fff;padding:22px;box-sizing:border-box}
    .bp-install-top{display:flex;gap:14px;align-items:center}.bp-install-icon{width:58px;height:58px;border-radius:16px;background:linear-gradient(135deg,#35d2e8,#4f7cff);display:grid;place-items:center;flex:0 0 auto;font-weight:950;font-size:24px;box-shadow:0 10px 30px rgba(53,210,232,.22)}
    .bp-install-eyebrow{font-size:10px;letter-spacing:.9px;color:#35d2e8;font-weight:900}.bp-install-title{font-size:22px;line-height:1.08;font-weight:950;margin-top:3px}.bp-install-copy{color:#b6c5d8;font-size:13px;line-height:1.55;margin:16px 0 13px}
    .bp-install-benefits{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:8px;margin:12px 0 17px}.bp-install-benefit{padding:10px;border-radius:12px;background:rgba(255,255,255,.035);border:1px solid rgba(255,255,255,.065);font-size:10px;color:#b6c5d8;min-width:0}.bp-install-benefit b{display:block;color:#fff;font-size:11px;margin-bottom:2px}
    #bp-install-steps{padding:13px 14px;border-radius:14px;background:rgba(53,210,232,.055);border:1px solid rgba(53,210,232,.13);margin:0 0 16px}.bp-install-step{display:flex;gap:10px;align-items:flex-start;padding:6px 0}.bp-install-num{width:22px;height:22px;border-radius:50%;display:grid;place-items:center;flex:0 0 auto;background:rgba(53,210,232,.14);color:#35d2e8;font-size:10px;font-weight:950}.bp-install-step-text{font-size:11px;line-height:1.4;color:#d7e1ed}.bp-install-step-text b{color:#fff}
    .bp-install-actions{display:grid;grid-template-columns:minmax(0,1fr) minmax(0,1fr) auto;gap:9px;width:100%;max-width:100%;box-sizing:border-box}.bp-install-primary,.bp-install-secondary,#bp-install-fallback-v441{appearance:none;-webkit-appearance:none;box-sizing:border-box;min-width:0;min-height:48px;border-radius:12px;padding:12px 15px;font:900 12px/1.2 system-ui,-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;cursor:pointer;text-align:center;touch-action:manipulation}.bp-install-primary{border:0;background:#35d2e8;color:#07111f}.bp-install-secondary,#bp-install-fallback-v441{background:#122238;color:#fff;border:1px solid rgba(255,255,255,.14)}.bp-install-note{font-size:9.5px;color:#8196ae;line-height:1.45;margin-top:11px;text-align:center}
    #bp-install-fallback-v441:focus-visible,.bp-install-primary:focus-visible,.bp-install-secondary:focus-visible{outline:3px solid rgba(255,226,91,.8);outline-offset:3px}
    @supports(height:100dvh){#bp-install-card{max-height:calc(100dvh - 28px)}}
    @media(max-width:620px){#bp-install-backdrop{padding:max(10px,env(safe-area-inset-top)) max(10px,env(safe-area-inset-right)) max(10px,env(safe-area-inset-bottom)) max(10px,env(safe-area-inset-left));align-items:flex-end}#bp-install-card{width:100%;max-width:100%;max-height:calc(100vh - 20px);border-radius:22px 22px 16px 16px;padding:18px}.bp-install-title{font-size:20px}.bp-install-benefits{display:none}.bp-install-actions{grid-template-columns:1fr!important;width:100%!important;max-width:100%!important;margin:0!important}.bp-install-primary,.bp-install-secondary,#bp-install-fallback-v441{width:100%!important;max-width:100%!important;min-width:0!important}.bp-install-note{margin-bottom:2px}}
    @supports(height:100dvh){@media(max-width:620px){#bp-install-card{max-height:calc(100dvh - max(20px,env(safe-area-inset-top)) - max(20px,env(safe-area-inset-bottom)))}}}
    @media(max-width:360px){#bp-install-card{padding:15px}.bp-install-top{gap:10px}.bp-install-icon{width:48px;height:48px;border-radius:14px;font-size:21px}.bp-install-title{font-size:18px}.bp-install-copy{margin:12px 0;font-size:12px}#bp-install-steps{padding:10px 11px;margin-bottom:12px}.bp-install-actions{gap:7px}}
    @media(max-height:600px) and (max-width:620px){.bp-install-copy{margin:9px 0}.bp-install-step{padding:4px 0}.bp-install-note{display:none}}
    @media(prefers-reduced-motion:reduce){#bp-install-backdrop,#bp-install-card{scroll-behavior:auto}}
  </style>
'''
if "</head>" not in web:
    raise SystemExit("V443 head anchor missing")
web = web.replace("</head>", style + "</head>", 1)

runtime = '''  <script>
  /* bridgepoint-v443-install-guide-runtime */
  (()=>{
    const dismissedKey='bridgepoint_install_dismissed_session_v310';
    const backdrop=document.getElementById('bp-install-backdrop');
    const fallback=document.getElementById('bp-install-fallback-v441');
    if(!backdrop||!fallback)return;
    const sync=()=>{
      const open=backdrop.classList.contains('show');
      backdrop.setAttribute('aria-hidden',open?'false':'true');
      if(open){backdrop.removeAttribute('inert');document.documentElement.style.overflow='hidden'}
      else{backdrop.setAttribute('inert','');document.documentElement.style.removeProperty('overflow')}
    };
    const continueIntoApp=event=>{
      event.preventDefault();
      try{sessionStorage.setItem(dismissedKey,'1')}catch(_){ }
      backdrop.classList.remove('show');
      sync();
      document.querySelector('flt-glass-pane,flutter-view,[role="main"],main')?.focus?.();
      try{window.bridgepointTrack?.('VALUE_VIEW',{surface:'install_continue',account_mode:'signin'})}catch(_){ }
    };
    fallback.addEventListener('click',continueIntoApp,{passive:false});
    new MutationObserver(sync).observe(backdrop,{attributes:true,attributeFilter:['class']});
    sync();
  })();
  </script>
'''
if "</body>" not in web:
    raise SystemExit("V443 body anchor missing")
web = web.replace("</body>", runtime + "</body>", 1)

checks = [
    marker,
    "#bp-install-backdrop:not(.show){visibility:hidden;pointer-events:none}",
    "Continue to BridgePoint",
    "showInstall(force=false)",
    "showInstall(true)",
    "new MutationObserver(sync)",
    "min-height:48px",
    "@media(max-width:360px)",
]
missing = [item for item in checks if item not in web]
if missing:
    raise SystemExit(f"V443 invariant failure: {missing}")

web_path.write_text(web, encoding="utf-8")
print("Applied V443 install-guide runtime repair: restored styling, truthful continuation, and mobile-safe dismissal.")
