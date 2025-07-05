const cacheName = 'cache-v150-20250530-1';
const precacheResources = [
    './',
    'index.html',
    'main.css',
    'main.js',
    'apple-touch-icon.png',
    'favicon-32x32.png',
    'favicon-16x16.png',
    'site.webmanifest',
    'safari-pinned-tab.svg',
    'android-chrome-192x192.png',
    'android-chrome-512x512.png'
];
self.addEventListener('install', (event) => {
    event.waitUntil(
      caches.open(cacheName).then((cache) => cache.addAll(precacheResources)));
    self.skipWaiting();
});

self.addEventListener('activate', (event) => {
    const cachesToKeep = [cacheName];

    event.waitUntil(
      caches.keys().then((keyList) =>
        Promise.all(
          keyList.map((key) => {
              if (!cachesToKeep.includes(key)) {
                  return caches.delete(key);
              }
          })
        )
      )
    );
});

self.addEventListener('fetch', (event) => {
    event.respondWith(
      caches.match(event.request).then((cachedResponse) => {
          if (cachedResponse) {
              return cachedResponse;
          }
          return fetch(event.request);
      })
    );
});
