/* coi-serviceworker v0.1.7 - Guido Zuidhof, licensed under MIT */
self.addEventListener("install", () => self.skipWaiting());
self.addEventListener("activate", e => e.waitUntil(self.clients.claim()));
self.addEventListener("fetch", e => {
  if (e.request.cache === "only-if-cached" && e.request.mode !== "same-origin") return;
  e.respondWith(
    e.request.url.startsWith(self.location.origin)
      ? fetch(e.request, { cache: "no-store" }).then(r =>
          new Response(r.body, {
            ...r,
            headers: new Headers({
              ...Object.fromEntries(r.headers),
              "Cross-Origin-Opener-Policy": "same-origin",
              "Cross-Origin-Embedder-Policy": "require-corp",
            }),
          })
        )
      : fetch(e.request)
  );
});
