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
  <meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">
  <meta name="theme-color" content="#0a5f9c">
  <meta name="description" content="Install ${APP_NAME} - ${APP_SUBTITLE} for iOS">
  <title>Install ${APP_NAME}</title>
  <style>
    * { box-sizing: border-box; }
    html { color-scheme: dark; }
    body {
      margin: 0;
      padding: 0;
      min-height: 100dvh;
      display: flex;
      align-items: center;
      justify-content: center;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif;
      background: linear-gradient(135deg, #0a3d7a 0%, #0a5f9c 50%, #062c4a 100%);
      overflow-x: hidden;
    }
    
    .container {
      width: 100%;
      max-width: 480px;
      padding: 20px;
    }
    
    .card {
      border-radius: 20px;
      padding: 32px 24px;
      text-align: center;
      background: rgba(255, 255, 255, 0.08);
      border: 1px solid rgba(255, 255, 255, 0.2);
      backdrop-filter: blur(20px) saturate(180%);
      box-shadow: 0 8px 32px 0 rgba(31, 38, 135, 0.37);
      animation: slideIn 0.6s ease-out;
    }
    
    @keyframes slideIn {
      from {
        opacity: 0;
        transform: translateY(20px);
      }
      to {
        opacity: 1;
        transform: translateY(0);
      }
    }
    
    .icon {
      width: 80px;
      height: 80px;
      margin: 0 auto 20px;
      background: linear-gradient(135deg, #7cc8f5, #0a5f9c);
      border-radius: 20px;
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 40px;
      box-shadow: 0 8px 16px rgba(4, 40, 80, 0.4);
    }
    
    h1 {
      margin: 0 0 8px 0;
      font-size: 28px;
      font-weight: 700;
      color: #ffffff;
      letter-spacing: -0.5px;
    }
    
    .subtitle {
      color: #bfe9ff;
      font-size: 14px;
      margin: 0 0 24px 0;
      font-weight: 500;
    }
    
    .description {
      color: #d4e9ff;
      font-size: 15px;
      line-height: 1.6;
      margin: 0 0 28px 0;
    }
    
    .buttons {
      display: flex;
      flex-direction: column;
      gap: 12px;
    }
    
    a.btn {
      display: block;
      text-decoration: none;
      font-weight: 600;
      font-size: 16px;
      padding: 14px 20px;
      border-radius: 14px;
      transition: all 0.3s ease;
      cursor: pointer;
      border: 2px solid transparent;
    }
    
    a.btn-primary {
      background: linear-gradient(135deg, #7cc8f5 0%, #5ab3f0 100%);
      color: #03245a;
      box-shadow: 0 8px 16px rgba(124, 200, 245, 0.3);
    }
    
    a.btn-primary:active {
      transform: scale(0.98);
      box-shadow: 0 4px 8px rgba(124, 200, 245, 0.3);
    }
    
    a.btn-secondary {
      background: transparent;
      color: #7cc8f5;
      border: 2px solid rgba(124, 200, 245, 0.5);
      font-size: 15px;
    }
    
    a.btn-secondary:active {
      background: rgba(124, 200, 245, 0.1);
    }
    
    .footer {
      margin-top: 28px;
      padding-top: 24px;
      border-top: 1px solid rgba(255, 255, 255, 0.1);
    }
    
    .hint-title {
      color: #7cc8f5;
      font-size: 12px;
      font-weight: 600;
      text-transform: uppercase;
      letter-spacing: 0.5px;
      margin: 0 0 8px 0;
    }
    
    .url-box {
      background: rgba(0, 0, 0, 0.3);
      padding: 10px 12px;
      border-radius: 10px;
      border: 1px solid rgba(255, 255, 255, 0.1);
      word-break: break-all;
      font-family: "Monaco", "Courier New", monospace;
      font-size: 12px;
      color: #bfe9ff;
      line-height: 1.4;
    }
    
    .note {
      font-size: 12px;
      color: #a0d5ff;
      margin: 12px 0 0 0;
    }
    
    @media (max-width: 380px) {
      .card {
        padding: 24px 18px;
      }
      h1 {
        font-size: 24px;
      }
      .icon {
        width: 64px;
        height: 64px;
        font-size: 32px;
      }
    }
  </style>
</head>
<body>
  <div class="container">
    <div class="card">
      <div class="icon">📱</div>
      <h1>${APP_NAME}</h1>
      <div class="subtitle">${APP_SUBTITLE}</div>
      <div class="description">
        Add the source to SideStore or AltStore to get 1-tap installations and automatic updates.
      </div>
      
      <div class="buttons">
        <a class="btn btn-primary" href="${sidestore}">Add to SideStore</a>
        <a class="btn btn-secondary" href="${altstore}">or use AltStore</a>
      </div>
      
      <div class="footer">
        <div class="hint-title">Source URL</div>
        <div class="url-box">${feed}</div>
        <div class="note">SideStore / AltStore must be installed to continue.</div>
      </div>
    </div>
  </div>
  
  <script>
    // Auto-open the SideStore deep link once on load
    setTimeout(function() {
      location.href = ${JSON.stringify(sidestore)};
    }, 400);
  </script>
</body>
</html>`;
}
