// ═══════════════════════════════════════════════════════
// Gyártásnyomkövető Scanner – Service Worker
// Verzió változásakor automatikusan frissül
// ═══════════════════════════════════════════════════════

// FONTOS: ezt a számot változtasd meg minden deploykor!
// Pl: v1.0 → v1.1 → v2.0
const CACHE_VERSION = 'scanner-v1.7';

const CACHED_FILES = [
  './',
  './index.html',
  './manifest.json',
];

// ── Telepítés: cache feltöltése ──────────────────────────
self.addEventListener('install', function(event) {
  console.log('[SW] Telepítés:', CACHE_VERSION);
  event.waitUntil(
    caches.open(CACHE_VERSION).then(function(cache) {
      return cache.addAll(CACHED_FILES);
    }).then(function() {
      // Azonnal aktiválódik, nem vár a régi SW leállására
      return self.skipWaiting();
    })
  );
});

// ── Aktiválás: régi cache-ek törlése ────────────────────
self.addEventListener('activate', function(event) {
  console.log('[SW] Aktiválás:', CACHE_VERSION);
  event.waitUntil(
    caches.keys().then(function(cacheNames) {
      return Promise.all(
        cacheNames
          .filter(function(name) { return name !== CACHE_VERSION; })
          .map(function(name) {
            console.log('[SW] Régi cache törölve:', name);
            return caches.delete(name);
          })
      );
    }).then(function() {
      // Azonnal átveszi az irányítást az összes tab felett
      return self.clients.claim();
    })
  );
});

// ── Fetch: hálózat először, cache fallback ───────────────
// Network-first stratégia: mindig a legfrissebb verziót
// tölti le, csak hiba esetén nyúl a cache-hez
self.addEventListener('fetch', function(event) {
  // Csak ugyanarról a domainről érkező kéréseket kezeljük
  if (!event.request.url.startsWith(self.location.origin)) return;

  event.respondWith(
    fetch(event.request)
      .then(function(networkResponse) {
        // Sikeres letöltés → cache frissítése
        if (networkResponse && networkResponse.status === 200) {
          var responseClone = networkResponse.clone();
          caches.open(CACHE_VERSION).then(function(cache) {
            cache.put(event.request, responseClone);
          });
        }
        return networkResponse;
      })
      .catch(function() {
        // Nincs internet → cache-ből szolgál ki
        return caches.match(event.request).then(function(cached) {
          if (cached) return cached;
          // Ha semmi nincs cache-ben, üres response
          return new Response('Offline – nincs kapcsolat', {
            status: 503,
            statusText: 'Service Unavailable'
          });
        });
      })
  );
});

// ── Frissítés értesítés a kliensnek ─────────────────────
self.addEventListener('message', function(event) {
  if (event.data && event.data.type === 'SKIP_WAITING') {
    self.skipWaiting();
  }
});
