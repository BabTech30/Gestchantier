// Service Worker — strategie network-first avec fallback cache
// Pour un SaaS avec donnees live, on prefere toujours le reseau,
// et on utilise le cache UNIQUEMENT en cas de coupure (mode chantier).

const CACHE = 'gc-v1';
const SHELL = [
  '/',
  '/app.html',
  '/manifest.webmanifest',
  '/icon.svg',
];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE).then((cache) => cache.addAll(SHELL)).catch(() => {})
  );
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k)))
    )
  );
  self.clients.claim();
});

self.addEventListener('fetch', (event) => {
  const req = event.request;

  // Ne pas mettre en cache les requetes Supabase (donnees live + auth)
  if (req.method !== 'GET' || /supabase\.co/.test(req.url)) return;

  // Same-origin uniquement (pas le CDN tailwind, pas esm.sh)
  const url = new URL(req.url);
  if (url.origin !== self.location.origin) return;

  event.respondWith(
    fetch(req)
      .then((res) => {
        const clone = res.clone();
        caches.open(CACHE).then((cache) => cache.put(req, clone)).catch(() => {});
        return res;
      })
      .catch(() => caches.match(req).then((c) => c || caches.match('/app.html')))
  );
});
