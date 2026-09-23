const CACHE = 'youmma-gn-v11';
const APP_SHELL = ['/youmma-gn.html', '/manifest-gn.json'];

self.addEventListener('install', (e) => {
  e.waitUntil(caches.open(CACHE).then((c) => c.addAll(APP_SHELL)));
  self.skipWaiting();
});

self.addEventListener('activate', (e) => {
  e.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k)))
    )
  );
  self.clients.claim();
});

self.addEventListener('fetch', (e) => {
  const url = e.request.url;

  // Ne jamais mettre en cache les appels Supabase — toujours en ligne, données à jour
  if (url.includes('supabase.co')) return;

  // Icônes : changent rarement -> cache-first
  if (url.includes('/icons/') && url.endsWith('.png')) {
    e.respondWith(
      caches.match(e.request).then((cached) =>
        cached ||
        fetch(e.request).then((res) => {
          const copie = res.clone();
          caches.open(CACHE).then((c) => c.put(e.request, copie));
          return res;
        })
      )
    );
    return;
  }

  // App shell (HTML, manifest) : network-first pour refléter immédiatement
  // les mises à jour du site ; le cache ne sert que si le réseau est indisponible.
  e.respondWith(
    fetch(e.request)
      .then((res) => {
        const copie = res.clone();
        caches.open(CACHE).then((c) => c.put(e.request, copie));
        return res;
      })
      .catch(() => caches.match(e.request))
  );
});
