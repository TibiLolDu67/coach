const C='cdl-v17';
self.addEventListener('install',e=>{e.waitUntil(caches.open(C).then(c=>c.addAll(['./','index.html','manifest.webmanifest','icon-192.png','icon-512.png'])));self.skipWaiting()});
self.addEventListener('activate',e=>{e.waitUntil(caches.keys().then(k=>Promise.all(k.filter(x=>x!==C).map(x=>caches.delete(x)))));self.clients.claim()});
self.addEventListener('fetch',e=>{if(e.request.method!=='GET'||!e.request.url.startsWith(self.location.origin))return;
 const net=fetch(e.request.url,{cache:'no-cache'}).then(r=>{if(!r.ok)return r;const cp=r.clone();return caches.open(C).then(c=>c.put(e.request,cp)).then(()=>r)});
 e.waitUntil(net.catch(()=>{}));
 e.respondWith(caches.match(e.request).then(m=>m||net.catch(()=>caches.match('./'))))});
