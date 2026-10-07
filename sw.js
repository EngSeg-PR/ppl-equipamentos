const CACHE='ppl-local-v25';
self.addEventListener('install',e=>e.waitUntil(caches.open(CACHE).then(c=>c.addAll(['./','index.html','style.css','corporate.css','management.css','easy-fill.css','equipment-home.css','worker-photo.css','simple-ui.css','simple-ui.js','catalog.js','cloud-config.js','cloud.js','management.js','management-backup.js','assets/ppl-logo-oficial.png','model.js','models.js','uuid.js','app.js','vendor/pdf-lib.min.js'])).then(()=>self.skipWaiting())));
self.addEventListener('activate',e=>e.waitUntil(caches.keys().then(keys=>Promise.all(keys.filter(k=>k.startsWith('ppl-local-')&&k!==CACHE).map(k=>caches.delete(k)))).then(()=>self.clients.claim())));
self.addEventListener('fetch',e=>{if(e.request.method==='GET'&&new URL(e.request.url).origin===location.origin)e.respondWith(caches.match(e.request).then(hit=>hit||fetch(e.request)));});




