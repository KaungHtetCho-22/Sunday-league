
self.addEventListener("message", event => {
  if (event.data?.type === "SKIP_WAITING") {
    self.skipWaiting();
  }
});

const CACHE_NAME = "sunday-league-v11-1";

const APP_SHELL = [
  "/",
  "/index.html",
  "/manifest.webmanifest",
  "/push-config.js",
  "/supabase-client.js",
  "/icons/icon-192.png",
  "/icons/icon-512.png",
  "/icons/apple-touch-icon.png"
];

self.addEventListener("install", event => {
  event.waitUntil(
    caches
      .open(CACHE_NAME)
      .then(cache => cache.addAll(APP_SHELL))
      .catch(error => {
        console.warn("App shell cache skipped:", error);
      })
  );
  self.skipWaiting();
});

self.addEventListener("activate", event => {
  event.waitUntil(
    caches
      .keys()
      .then(keys =>
        Promise.all(
          keys
            .filter(key => key !== CACHE_NAME)
            .map(key => caches.delete(key))
        )
      )
      .then(() => self.clients.claim())
  );
});

self.addEventListener("fetch", event => {
  if (event.request.method !== "GET") return;

  const requestUrl = new URL(event.request.url);

  if (event.request.mode === "navigate") {
    event.respondWith(
      fetch(event.request)
        .then(response => {
          const copy = response.clone();
          caches
            .open(CACHE_NAME)
            .then(cache =>
              cache.put("/index.html", copy)
            );
          return response;
        })
        .catch(() =>
          caches.match("/index.html")
        )
    );
    return;
  }

  if (requestUrl.origin === self.location.origin) {
    event.respondWith(
      caches.match(event.request).then(cached => {
        const network = fetch(event.request)
          .then(response => {
            if (response.ok) {
              const copy = response.clone();
              caches
                .open(CACHE_NAME)
                .then(cache =>
                  cache.put(event.request, copy)
                );
            }
            return response;
          })
          .catch(() => cached);

        return cached || network;
      })
    );
  }
});

self.addEventListener("push", event => {
  let payload = {
    title: "Sunday League",
    body: "There is a new Sunday League update.",
    url: "/",
    tag: "sunday-league-update"
  };

  try {
    if (event.data) {
      payload = {
        ...payload,
        ...event.data.json()
      };
    }
  } catch (_) {
    if (event.data) {
      payload.body = event.data.text();
    }
  }

  const options = {
    body: payload.body,
    icon: "/icons/icon-192.png",
    badge: "/icons/badge-96.png",
    tag: payload.tag,
    renotify: true,
    silent: false,
    vibrate: [220, 100, 220],
    timestamp: Date.now(),
    data: {
      url: payload.url || "/"
    }
  };

  event.waitUntil(
    Promise.all([
      self.registration.showNotification(
        payload.title,
        options
      ),
      self.clients
        .matchAll({
          type: "window",
          includeUncontrolled: true
        })
        .then(windowClients =>
          Promise.all(
            windowClients.map(client =>
              client.postMessage({
                type:
                  "SUNDAY_LEAGUE_PUSH_RECEIVED",
                payload
              })
            )
          )
        )
    ])
  );
});

self.addEventListener("notificationclick", event => {
  event.notification.close();

  const targetUrl =
    new URL(
      event.notification.data?.url || "/",
      self.location.origin
    ).href;

  event.waitUntil(
    clients.matchAll({
      type: "window",
      includeUncontrolled: true
    }).then(windowClients => {
      for (const client of windowClients) {
        if (
          client.url.startsWith(
            self.location.origin
          ) &&
          "focus" in client
        ) {
          return client
            .navigate(targetUrl)
            .then(() => client.focus());
        }
      }

      return clients.openWindow
        ? clients.openWindow(targetUrl)
        : undefined;
    })
  );
});
