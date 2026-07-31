const CACHE = 'nutriplan-v47';
// Relative Pfade – absolute '/...' Pfade zeigen auf den Domain-Root, nicht auf /NutriPlan/
const ASSETS = ['./', './index.html', './manifest.json',
  './icons/icon-192.png', './icons/icon-512.png', './icons/apple-touch-icon.png'];

self.addEventListener('install', e => {
  e.waitUntil(caches.open(CACHE).then(c => c.addAll(ASSETS)));
  self.skipWaiting();
});

self.addEventListener('activate', e => {
  e.waitUntil(caches.keys().then(keys =>
    Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k)))
  ));
  self.clients.claim();
});

self.addEventListener('fetch', e => {
  // API-Calls nie cachen
  if (e.request.url.includes('/api/')) return;

  const isDoc = e.request.mode === 'navigate' ||
                e.request.destination === 'document' ||
                e.request.url.endsWith('.html');

  if (isDoc) {
    // HTML immer frisch holen (umgeht abgestandenen CDN-/Browser-Cache)
    e.respondWith(
      fetch(e.request, { cache: 'reload' })
        .then(res => {
          caches.open(CACHE).then(c => c.put(e.request, res.clone()));
          return res;
        })
        .catch(() => caches.match(e.request))
    );
    return;
  }

  e.respondWith(fetch(e.request).catch(() => caches.match(e.request)));
});
