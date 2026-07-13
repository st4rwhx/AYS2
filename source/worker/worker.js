// ELORIS-PRISM — short-URL source proxy (Cloudflare Worker, free tier).
//
// Serves the SideStore/AltStore source.json at a short, memorable URL
// (e.g. https://elorisprism.<account>.workers.dev) instead of the long
// GitHub release path. It just proxies + caches the latest source.json from
// the rolling GitHub release, so nothing goes stale: every new build updates
// the release, and this Worker reflects it within the cache TTL.
//
// The IPA/icon download URLs *inside* source.json still point at GitHub
// Releases, so there is no bandwidth cost here — only the small JSON is served.

const UPSTREAM =
  "https://github.com/ayanodeath/ELORIS-PRISM/releases/download/latest/source.json";
const CACHE_TTL = 300; // seconds

export default {
  async fetch(request, _env, ctx) {
    // Only GET/HEAD make sense for a source feed.
    if (request.method !== "GET" && request.method !== "HEAD") {
      return new Response("Method Not Allowed", { status: 405 });
    }

    const cache = caches.default;
    const cacheKey = new Request(new URL(request.url).origin + "/source.json", request);

    let response = await cache.match(cacheKey);
    if (!response) {
      const upstream = await fetch(UPSTREAM, {
        cf: { cacheTtl: CACHE_TTL, cacheEverything: true },
        headers: { "user-agent": "eloris-prism-source-worker" },
      });
      if (!upstream.ok) {
        return new Response("source unavailable", { status: 502 });
      }
      const body = await upstream.text();
      response = new Response(body, {
        headers: {
          "content-type": "application/json; charset=utf-8",
          "cache-control": `public, max-age=${CACHE_TTL}`,
          "access-control-allow-origin": "*",
          "x-eloris-source": "cloudflare-worker",
        },
      });
      ctx.waitUntil(cache.put(cacheKey, response.clone()));
    }
    return response;
  },
};
