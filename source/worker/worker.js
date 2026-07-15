// AYS2 — source proxy + one-tap SideStore install redirect.
// Cloudflare Worker, free tier.
//
// Routes:
//   /  or  /source.json  → the SideStore/AltStore source feed (proxied+cached
//                          from the rolling GitHub release, so never stale).
//   /install (or /add)   → a web page that redirects to the SideStore deep link
//                          `sidestore://source?url=<this feed>`, so a normal
//                          https link becomes a one-tap "Add to SideStore".
//
// The IPA/icon download URLs inside source.json still point at GitHub Releases,
// so only the small JSON is served here — no bandwidth cost.

const UPSTREAM =
  "https://github.com/st4rwhx/AYS2/releases/download/latest/source.json";
const CACHE_TTL = 300; // seconds

export default {
  async fetch(request, _env, ctx) {
    if (request.method !== "GET" && request.method !== "HEAD") {
      return new Response("Method Not Allowed", { status: 405 });
    }

    const url = new URL(request.url);
    const path = url.pathname.replace(/\/+$/, "") || "/";

    // One-tap install / add-source redirect page.
    if (path === "/install" || path === "/add" || path === "/sidestore") {
      // The source feed is this Worker's own root.
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
  return `<!doctype html><html lang="en"><head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Add AYS2 to SideStore</title>
<style>
  :root{color-scheme:dark}
  *{box-sizing:border-box}
  body{margin:0;min-height:100vh;display:grid;place-items:center;padding:28px;
    font-family:-apple-system,"Segoe UI",system-ui,sans-serif;color:#eaf4ff;
    background:radial-gradient(120% 80% at 50% -10%,#7cc8f5,#0a5f9c 70%,#062c4a)}
  .card{width:100%;max-width:420px;text-align:center;padding:30px 24px;border-radius:26px;
    background:linear-gradient(180deg,rgba(255,255,255,.28),rgba(255,255,255,.10));
    border:1px solid rgba(255,255,255,.6);backdrop-filter:blur(14px);
    box-shadow:0 24px 60px -22px rgba(4,30,60,.8),inset 0 1px 0 rgba(255,255,255,.8)}
  h1{margin:6px 0 4px;font-size:24px}
  p{margin:0 0 22px;color:#dbeeff;font-size:14px;line-height:1.5}
  a.btn{display:block;text-decoration:none;font-weight:700;font-size:17px;color:#05243c;
    padding:15px;border-radius:16px;margin-bottom:12px;
    background:linear-gradient(180deg,#ffffff,#bfe9ff);
    box-shadow:0 10px 24px -8px rgba(4,40,80,.6),inset 0 1px 0 #fff}
  a.alt{background:transparent;color:#dff0ff;border:1px solid rgba(255,255,255,.45);
    box-shadow:none;font-size:14px;padding:12px}
  .hint{margin-top:16px;font-size:12px;color:#bcdcff}
  code{background:rgba(0,0,0,.25);padding:2px 6px;border-radius:6px;font-size:11px;word-break:break-all}
</style></head><body>
  <div class="card">
    <h1>Add AYS2</h1>
    <p>Opening SideStore to add the source. If nothing happens, tap the button.</p>
    <a class="btn" href="${sidestore}">Add to SideStore</a>
    <a class="btn alt" href="${altstore}">Use AltStore instead</a>
    <div class="hint">SideStore must already be installed. Source URL:<br><code>${feed}</code></div>
  </div>
  <script>
    // Auto-open the SideStore deep link once on load.
    setTimeout(function(){ location.href = ${JSON.stringify(sidestore)}; }, 350);
  </script>
</body></html>`;
}
