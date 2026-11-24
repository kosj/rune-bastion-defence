/* Rune Bastion service worker: offline play + instant repeat loads.
 * - Versioned requests (?v=<build id>: the gz parts of the engine and game data, index.js) are
 *   cache-first in the cache "rb-v-<build id>"; when a new build id shows up, older rb-v-* caches
 *   are dropped, so a deploy never mixes parts of two builds and old data does not pile up.
 * - Everything else (the page itself, icons, worklets) is network-first with a cache fallback,
 *   so updates arrive immediately online and the game still starts offline.
 */
const SHELL = 'rb-shell';
self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (e) => e.waitUntil(self.clients.claim()));
self.addEventListener('fetch', (e) => {
  const req = e.request;
  if (req.method !== 'GET') return;
  const url = new URL(req.url);
  if (url.origin !== self.location.origin) return;
  const v = url.searchParams.get('v');
  if (v) {
    e.respondWith((async () => {
      const name = 'rb-v-' + v;
      const cache = await caches.open(name);
      const hit = await cache.match(req);
      if (hit) return hit;
      const res = await fetch(req);
      if (res.ok) {
        await cache.put(req, res.clone());
        for (const k of await caches.keys()) {
          if (k.startsWith('rb-v-') && k !== name) await caches.delete(k);
        }
      }
      return res;
    })());
    return;
  }
  e.respondWith((async () => {
    const cache = await caches.open(SHELL);
    try {
      const res = await fetch(req);
      if (res.ok) await cache.put(req, res.clone());
      return res;
    } catch (err) {
      const hit = await cache.match(req, { ignoreSearch: req.mode === 'navigate' });
      if (hit) return hit;
      throw err;
    }
  })());
});
