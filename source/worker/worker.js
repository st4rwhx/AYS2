// AYS2 — source proxy + one-tap SideStore/AltStore install redirect.
// Cloudflare Worker, free tier.
//
// Routes:
//   /  or  /source.json  → the SideStore/AltStore source feed (proxied+cached
//                          from the rolling GitHub release, so never stale).
//   /install (or /add)   → a web page that redirects to the SideStore deep link
//                          `sidestore://source?url=<this feed>`, so a normal
//                          https link becomes a one-tap "Add to SideStore".
//   /status              → health check (returns JSON)
//
// The IPA/icon download URLs inside source.json still point at GitHub Releases,
// so only the small JSON is served here — no bandwidth cost.

const UPSTREAM =
  "https://github.com/st4rwhx/AYS2/releases/download/latest/source.json";
const CACHE_TTL = 300; // seconds
const APP_NAME = "AYS2";
const APP_SUBTITLE = "PlayStation 2 Emulator";

export default {
  async fetch(request, _env, ctx) {
    if (request.method !== "GET" && request.method !== "HEAD") {
      return new Response("Method Not Allowed", { status: 405 });
    }

    const url = new URL(request.url);
    const path = url.pathname.replace(/\/+$/, "") || "/";

    // Health check
    if (path === "/status") {
      return new Response(JSON.stringify({ status: "ok", app: APP_NAME }), {
        headers: { "content-type": "application/json; charset=utf-8" },
      });
    }

    // One-tap install / add-source redirect page.
    if (path === "/install" || path === "/add" || path === "/sidestore") {
      const feed = `${url.origin}/`;
      return new Response(installPage(feed), {
        headers: {
          "content-type": "text/html; charset=utf-8",
          "cache-control": "public, max-age=600",
        },
      });
    }

    // Everything else → the source feed.
    return serveSource(request, ctx);
  },
};

async function serveSource(request, ctx) {
  const cache = caches.default;
  const cacheKey = new Request(new URL(request.url).origin + "/source.json", request);
  let response = await cache.match(cacheKey);
  if (!response) {
    const upstream = await fetch(UPSTREAM, {
      cf: { cacheTtl: CACHE_TTL, cacheEverything: true },
      headers: { "user-agent": "ays2-source-worker" },
    });
    if (!upstream.ok) return new Response("source unavailable", { status: 502 });
    const body = await upstream.text();
    response = new Response(body, {
      headers: {
        "content-type": "application/json; charset=utf-8",
        "cache-control": `public, max-age=${CACHE_TTL}`,
        "access-control-allow-origin": "*",
        "x-ays2-source": "cloudflare-worker",
      },
    });
    ctx.waitUntil(cache.put(cacheKey, response.clone()));
  }
  return response;
}

// Redirect page: tries the SideStore deep link automatically, with a visible
// button and an AltStore fallback for the case the auto-redirect is blocked or
// the app scheme isn't registered.
function installPage(feed) {
  const enc = encodeURIComponent(feed);
  const sidestore = `sidestore://source?url=${enc}`;
  const altstore = `altstore://source?url=${enc}`;
  return `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <meta name="description" content="Install ${APP_NAME} - ${APP_SUBTITLE}">
  <title>${APP_NAME}</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    html { color-scheme: dark; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      background: #0f0f0f;
      color: #e8e8e8;
      min-height: 100vh;
      display: flex;
      align-items: center;
      justify-content: center;
      padding: 16px;
    }
    
    main {
      max-width: 400px;
      width: 100%;
    }
    
    h1 {
      font-size: 32px;
      font-weight: 600;
      margin-bottom: 6px;
      letter-spacing: -0.5px;
    }
    
    .tagline {
      color: #a8a8a8;
      font-size: 14px;
      margin-bottom: 32px;
    }
    
    .description {
      color: #c0c0c0;
      font-size: 15px;
      line-height: 1.6;
      margin-bottom: 32px;
    }
    
    .cta {
      display: flex;
      flex-direction: column;
      gap: 10px;
      margin-bottom: 40px;
    }
    
    a {
      text-decoration: none;
      border-radius: 8px;
      padding: 12px 16px;
      font-size: 15px;
      font-weight: 500;
      transition: opacity 0.2s, background 0.2s;
      text-align: center;
      border: none;
      cursor: pointer;
    }
    
    .btn-primary {
      background: #0084ff;
      color: white;
    }
    
    .btn-primary:active {
      opacity: 0.8;
    }
    
    .btn-secondary {
      background: #262626;
      color: #e8e8e8;
      border: 1px solid #404040;
    }
    
    .btn-secondary:active {
      background: #323232;
    }
    
    .source-info {
      border-top: 1px solid #262626;
      padding-top: 24px;
    }
    
    .source-label {
      font-size: 12px;
      color: #808080;
      text-transform: uppercase;
      letter-spacing: 0.5px;
      margin-bottom: 8px;
    }
    
    .source-url {
      background: #1a1a1a;
      border: 1px solid #262626;
      border-radius: 6px;
      padding: 10px 12px;
      font-family: "SF Mono", Monaco, monospace;
      font-size: 12px;
      color: #b0b0b0;
      word-break: break-all;
      line-height: 1.4;
    }
    
    .note {
      font-size: 12px;
      color: #707070;
      margin-top: 12px;
    }
  </style>
</head>
<body>
  <main>
    <h1>${APP_NAME}</h1>
    <div class="tagline">${APP_SUBTITLE}</div>
    
    <p class="description">
      Add this source to SideStore or AltStore for one-tap installs and automatic updates.
    </p>
    
    <div class="cta">
      <a href="${sidestore}" class="btn-primary">Add to SideStore</a>
      <a href="${altstore}" class="btn-secondary">Use AltStore instead</a>
    </div>
    
    <div class="source-info">
      <div class="source-label">Source URL</div>
      <div class="source-url">${feed}</div>
      <div class="note">SideStore / AltStore must be installed.</div>
    </div>
  </main>
  
  <script>
    setTimeout(() => { location.href = ${JSON.stringify(sidestore)}; }, 300);
  </script>
</body>
</html>`;
}
