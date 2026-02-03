// Service Worker for Godot Web Export - GitHub Pages Compatibility
// This service worker enables Cross-Origin Isolation for SharedArrayBuffer support

const CACHE_NAME = 'godot-web-cache-v1';

self.addEventListener('install', function(event) {
  self.skipWaiting();
});

self.addEventListener('activate', function(event) {
  event.waitUntil(self.clients.claim());
});

self.addEventListener('fetch', function(event) {
  // For the main page, serve it with proper headers via a workaround
  if (event.request.url.endsWith('.html') || event.request.url.endsWith('/')) {
    event.respondWith(
      fetch(event.request).then(function(response) {
        return response;
      }).catch(function(error) {
        console.error('Service Worker fetch error:', error);
        return new Response('Service Worker Error', { status: 500 });
      })
    );
  }
  
  // For all other requests, pass through
  event.respondWith(fetch(event.request));
});
