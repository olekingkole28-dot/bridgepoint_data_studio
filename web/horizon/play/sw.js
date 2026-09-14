const CACHE='bridgepoint-horizon-play-v4302';
const SHELL=[
  './',
  './index.html',
  './styles.css',
  './app.js',
  './runtime-contract.js',
  './manifest.webmanifest',
  '../horizon-mark.svg'
];

self.addEventListener('install',event=>{
  event.waitUntil(
    caches.open(CACHE)
      .then(cache=>cache.addAll(SHELL))
      .then(()=>self.skipWaiting())
  );
});

self.addEventListener('activate',event=>{
  event.waitUntil(
    caches.keys()
      .then(keys=>Promise.all(keys.filter(k=>k!==CACHE&&k.startsWith('bridgepoint-horizon-play-')).map(k=>caches.delete(k))))
      .then(()=>self.clients.claim())
  );
});

self.addEventListener('fetch',event=>{
  const req=event.request;
  if(req.method!=='GET') return;
  const u=new URL(req.url);

  if(
    u.hostname.endsWith('supabase.co') ||
    u.hostname.includes('google.com') ||
    u.hostname.includes('jsdelivr.net') ||
    u.protocol==='wss:'
  ) return;

  if(req.mode==='navigate'){
    event.respondWith(
      fetch(req).then(r=>{
        const copy=r.clone();
        caches.open(CACHE).then(c=>c.put('./index.html',copy)).catch(()=>{});
        return r;
      }).catch(()=>caches.match('./index.html'))
    );
    return;
  }

  event.respondWith(
    caches.match(req).then(cached=>{
      const network=fetch(req).then(r=>{
        if(r && r.ok && u.origin===self.location.origin){
          const copy=r.clone();
          caches.open(CACHE).then(c=>c.put(req,copy)).catch(()=>{});
        }
        return r;
      }).catch(()=>cached);
      return cached||network;
    })
  );
});