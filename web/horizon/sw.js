const CACHE='bridgepoint-horizon-v4302';
const SHELL=[
  './','./index.html','./manifest.webmanifest','./horizon-mark.svg',
  './play/','./play/index.html','./play/styles.css','./play/app.js',
  './play/runtime-contract.js','./play/manifest.webmanifest'
];
self.addEventListener('install',event=>{
  event.waitUntil(caches.open(CACHE).then(cache=>cache.addAll(SHELL)).then(()=>self.skipWaiting()));
});
self.addEventListener('activate',event=>{
  event.waitUntil(caches.keys().then(keys=>Promise.all(keys.filter(k=>k.startsWith('bridgepoint-horizon-')&&k!==CACHE).map(k=>caches.delete(k)))).then(()=>self.clients.claim()));
});
self.addEventListener('fetch',event=>{
  const req=event.request;
  if(req.method!=='GET') return;
  const u=new URL(req.url);
  if(u.hostname.endsWith('supabase.co')||u.hostname.includes('jsdelivr.net')||u.hostname.includes('google.com')) return;
  if(req.mode==='navigate'){
    event.respondWith(fetch(req).catch(()=>u.pathname.includes('/play/')?caches.match('./play/index.html'):caches.match('./index.html')));
    return;
  }
  event.respondWith(
    fetch(req).then(r=>{
      if(r.ok&&u.origin===self.location.origin){
        const copy=r.clone();caches.open(CACHE).then(c=>c.put(req,copy)).catch(()=>{});
      }
      return r;
    }).catch(()=>caches.match(req))
  );
});