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
    
    .community {
      margin-top: 40px;
      padding-top: 32px;
      border-top: 1px solid #262626;
    }
    
    .community-title {
      font-size: 12px;
      color: #808080;
      text-transform: uppercase;
      letter-spacing: 0.5px;
      margin-bottom: 16px;
      text-align: center;
    }
    
    .community-links {
      display: flex;
      gap: 16px;
      justify-content: center;
    }
    
    .community-btn {
      display: flex;
      align-items: center;
      justify-content: center;
      width: 48px;
      height: 48px;
      border-radius: 8px;
      border: 1px solid #333333;
      background: transparent;
      color: #909090;
      transition: all 0.2s;
      text-decoration: none;
    }
    
    .community-btn svg {
      width: 24px;
      height: 24px;
    }
    
    .community-btn.github:hover {
      background: #1a1a1a;
      color: #ffffff;
      border-color: #505050;
    }
    
    .community-btn.discord:hover {
      background: #5865f2;
      color: #ffffff;
      border-color: #5865f2;
    }
    
    .app-footer {
      margin-top: 48px;
      padding-top: 32px;
      border-top: 1px solid #262626;
      font-size: 13px;
    }
    
    .footer-section {
      margin-bottom: 24px;
    }
    
    .footer-label {
      color: #808080;
      text-transform: uppercase;
      letter-spacing: 0.5px;
      font-size: 11px;
      margin: 0 0 8px 0;
    }
    
    .footer-text {
      color: #a0a0a0;
      line-height: 1.6;
      margin: 0;
    }
    
    .footer-link {
      color: #5ab3f0;
      text-decoration: none;
      transition: color 0.2s;
    }
    
    .footer-link:hover {
      color: #7cc8f5;
    }
    
    .footer-bottom {
      padding-top: 24px;
      border-top: 1px solid #262626;
      margin-top: 24px;
    }
    
    .copyright {
      color: #808080;
      font-size: 12px;
      margin: 0;
      line-height: 1.4;
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
    
    <div class="community">
      <div class="community-title">Join the community</div>
      <div class="community-links">
        <a href="https://github.com/st4rwhx/AYS2" class="community-btn github" title="GitHub Repository">
          <svg viewBox="0 0 24 24" fill="currentColor"><path d="M12 0c-6.626 0-12 5.373-12 12 0 5.302 3.438 9.8 8.207 11.387.599.111.793-.261.793-.577v-2.234c-3.338.726-4.033-1.416-4.033-1.416-.546-1.387-1.333-1.756-1.333-1.756-1.089-.745.083-.729.083-.729 1.205.084 1.839 1.237 1.839 1.237 1.07 1.834 2.807 1.304 3.492.997.107-.775.418-1.305.762-1.604-2.665-.305-5.467-1.334-5.467-5.931 0-1.311.469-2.381 1.236-3.221-.124-.303-.535-1.524.117-3.176 0 0 1.008-.322 3.301 1.23.957-.266 1.983-.399 3.003-.404 1.02.005 2.047.138 3.006.404 2.291-1.552 3.297-1.23 3.297-1.23.653 1.653.242 2.874.118 3.176.77.84 1.235 1.911 1.235 3.221 0 4.609-2.807 5.624-5.479 5.921.43.372.823 1.102.823 2.222v 3.293c0 .319.192.694.801.576 4.765-1.589 8.199-6.086 8.199-11.386 0-6.627-5.373-12-12-12z"/></svg>
        </a>
        <a href="https://discord.gg/AXAzExECSv" class="community-btn discord" title="Discord Server">
          <svg viewBox="0 0 24 24" fill="currentColor"><path d="M20.317 4.37a19.791 19.791 0 0 0-4.885-1.515.074.074 0 0 0-.079.037c-.211.375-.444.864-.607 1.25a18.27 18.27 0 0 0-5.487 0c-.163-.386-.395-.875-.607-1.25a.077.077 0 0 0-.079-.037A19.736 19.736 0 0 0 3.677 4.37a.07.07 0 0 0-.032.027C.533 9.046-.32 13.58.099 18.057a.082.082 0 0 0 .031.056 19.9 19.9 0 0 0 5.993 3.03.078.078 0 0 0 .084-.028c.462-.63.873-1.295 1.226-1.994a.076.076 0 0 0-.042-.106 13.107 13.107 0 0 1-1.872-.892.077.077 0 0 1-.008-.128c.126-.094.252-.192.372-.291a.074.074 0 0 1 .076-.01c3.928 1.793 8.18 1.793 12.062 0a.074.074 0 0 1 .078.009c.12.099.246.198.373.292a.077.077 0 0 1-.006.127 12.299 12.299 0 0 1-1.873.892.076.076 0 0 0-.041.107c.352.699.764 1.365 1.225 1.994a.077.077 0 0 0 .084.028 19.863 19.863 0 0 0 6.002-3.03.077.077 0 0 0 .032-.054c.5-4.718-.838-8.812-3.551-12.742a.061.061 0 0 0-.031-.028zM8.02 15.33c-1.183 0-2.157-.965-2.157-2.156 0-1.193.948-2.156 2.157-2.156 1.211 0 2.176.963 2.157 2.156 0 1.191-.946 2.156-2.157 2.156zm7.975 0c-1.183 0-2.157-.965-2.157-2.156 0-1.193.948-2.156 2.157-2.156 1.211 0 2.176.963 2.157 2.156 0 1.191-.946 2.156-2.157 2.156z"/></svg>
        </a>
      </div>
    </div>
    
    <div class="source-info">
      <div class="source-label">Source URL</div>
      <div class="source-url">${feed}</div>
      <div class="note">SideStore / AltStore must be installed.</div>
    </div>
    
    <div class="footer-links">
      <a href="https://github.com/st4rwhx/AYS2" class="link-btn">
        <span class="link-icon">⚙️</span> Source Code
      </a>
    </div>
    
    <footer class="app-footer">
      <div class="footer-section">
        <p class="footer-text">
          ${APP_NAME} is a PlayStation 2 emulator based on ARMSX2, 
          licensed under <strong>GNU General Public License v3.0</strong>.
        </p>
      </div>
      
      <div class="footer-section">
        <p class="footer-label">GPL-3.0 Compliance</p>
        <p class="footer-text">
          The complete source code is available at 
          <a href="https://github.com/st4rwhx/AYS2" class="footer-link">GitHub</a>.
          See <strong>SOURCE-OFFER.txt</strong> in releases for GPL compliance details.
        </p>
      </div>
      
      <div class="footer-bottom">
        <p class="copyright">
          © 2024-2026 AYS2 Contributors • Based on <a href="https://github.com/ARMSX2/armsx2-ios" class="footer-link">ARMSX2</a> • 
          <a href="https://github.com/st4rwhx/AYS2/blob/main/LICENSE" class="footer-link">View License</a>
        </p>
      </div>
    </footer>
  </main>
  
  <script>
    setTimeout(() => { location.href = ${JSON.stringify(sidestore)}; }, 300);
  </script>
</body>
</html>`;
}
