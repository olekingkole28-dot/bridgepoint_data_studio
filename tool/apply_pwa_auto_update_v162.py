from pathlib import Path
import runpy

path=Path('web/index.html')
text=path.read_text(encoding='utf-8')
original=text

def replace_once(old,new,label):
    global text
    count=text.count(old)
    if count!=1:
        raise SystemExit(f'{label}: expected exactly 1 match, found {count}')
    text=text.replace(old,new,1)

replace_once(
'''  <meta name="theme-color" content="#07111F">\n''',
'''  <meta name="theme-color" content="#07111F">\n  <meta http-equiv="Cache-Control" content="no-cache, no-store, must-revalidate">\n  <meta http-equiv="Pragma" content="no-cache">\n  <meta http-equiv="Expires" content="0">\n''',
'no-cache-meta')

style_marker='''    @media(max-width:600px){#bp-expansion-launcher{right:12px;bottom:12px}#bp-expansion-panel{right:12px;bottom:62px}.bp-exp-row{align-items:stretch;flex-direction:column}.bp-exp-row .bp-btn{width:100%}}\n'''
style_add=style_marker+'''    #bp-update-toast{display:none;position:fixed;left:50%;top:16px;transform:translateX(-50%);z-index:2147483646;max-width:min(560px,calc(100vw - 24px));padding:10px 14px;border-radius:12px;background:rgba(8,23,39,.97);border:1px solid rgba(53,210,232,.35);box-shadow:0 12px 38px rgba(0,0,0,.42);color:#fff;font:800 11px/1.35 system-ui,-apple-system,Segoe UI,sans-serif;backdrop-filter:blur(12px)}\n    #bp-update-toast.show{display:flex;align-items:center;gap:9px}#bp-update-toast .pulse{width:8px;height:8px;border-radius:50%;background:#35d2e8;box-shadow:0 0 12px rgba(53,210,232,.7);flex:0 0 auto}\n'''
if style_marker not in text:
    raise SystemExit('update toast style marker missing')
text=text.replace(style_marker,style_add,1)

replace_once(
'''<body>\n  <script src="flutter_bootstrap.js" async></script>\n''',
'''<body>\n  <div id="bp-update-toast" role="status" aria-live="polite"><span class="pulse"></span><span id="bp-update-message">BridgePoint is updating…</span></div>\n\n  <script>\n  (()=>{\n    const releaseKey='bridgepoint_release_v162';\n    const checkEveryMs=60000;\n    let applying=false;\n    const toast=document.getElementById('bp-update-toast');\n    const message=document.getElementById('bp-update-message');\n\n    function show(text){if(message)message.textContent=text;if(toast)toast.classList.add('show');}\n    function releaseUrl(){return new URL(`bridgepoint-release.json?t=${Date.now()}`,document.baseURI).toString();}\n    async function currentRelease(){\n      const response=await fetch(releaseUrl(),{cache:'no-store',headers:{'Cache-Control':'no-cache'}});\n      if(!response.ok)throw new Error(`release ${response.status}`);\n      const payload=await response.json();\n      return String(payload.version||payload.sha||payload.release||'').trim();\n    }\n    async function clearFlutterShell(){\n      if('serviceWorker' in navigator){\n        const basePath=new URL(document.baseURI).pathname;\n        const registrations=await navigator.serviceWorker.getRegistrations();\n        await Promise.all(registrations.filter(r=>{try{return new URL(r.scope).pathname.startsWith(basePath)}catch(_){return false}}).map(r=>r.unregister()));\n      }\n      if('caches' in window){\n        const keys=await caches.keys();\n        const stale=keys.filter(k=>k==='flutter-app-cache'||k==='flutter-temp-cache'||k==='flutter-app-manifest'||k.startsWith('flutter-app-'));\n        await Promise.all(stale.map(k=>caches.delete(k)));\n      }\n    }\n    async function applyRelease(next){\n      if(applying||!next)return;\n      applying=true;\n      show('A new BridgePoint version is ready — updating automatically…');\n      localStorage.setItem(releaseKey,next);\n      sessionStorage.setItem('bridgepoint_auto_update_restoring','1');\n      try{await clearFlutterShell()}catch(_){ }\n      show('BridgePoint updated — restoring your workspace…');\n      await new Promise(resolve=>setTimeout(resolve,650));\n      const target=new URL(location.href);\n      target.searchParams.set('bpv',next.slice(0,16));\n      location.replace(target.toString());\n    }\n    async function check(){\n      if(applying)return;\n      try{\n        const next=await currentRelease();\n        if(!next)return;\n        const previous=localStorage.getItem(releaseKey);\n        if(!previous){localStorage.setItem(releaseKey,next);return;}\n        if(previous!==next)await applyRelease(next);\n      }catch(_){/* Update checks never interrupt BridgePoint. */}\n    }\n    window.bridgePointCheckForUpdate=check;\n    window.addEventListener('load',()=>{\n      if(sessionStorage.getItem('bridgepoint_auto_update_restoring')==='1'){\n        sessionStorage.removeItem('bridgepoint_auto_update_restoring');\n        show('BridgePoint is up to date.');\n        setTimeout(()=>toast?.classList.remove('show'),2200);\n      }\n      setTimeout(check,4500);\n      setInterval(check,checkEveryMs);\n    });\n    window.addEventListener('online',check);\n    document.addEventListener('visibilitychange',()=>{if(!document.hidden)check()});\n  })();\n  </script>\n\n  <script src="flutter_bootstrap.js" async></script>\n''',
'auto-update-runtime')

if text==original:
    raise SystemExit('No PWA auto-update changes applied')
path.write_text(text,encoding='utf-8')
print('Applied installed-app automatic update runtime v162')

# The install guide must be part of every release that receives the PWA runtime.
runpy.run_path('tool/apply_pwa_install_onboarding_v310.py',run_name='__main__')

# Normalize only formatting boundaries used by the historical v164 generator.
runpy.run_path('tool/repair_dashboard_widgets_compat_v813.py',run_name='__main__')
