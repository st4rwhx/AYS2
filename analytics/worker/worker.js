// ELORIS-PRISM telemetry ingest — Cloudflare Worker.
// SPDX-License-Identifier: GPL-3.0+
//
// Receives anonymous crash/error reports POSTed by the app and files them as
// GitHub issues (deduped by a fingerprint). The GitHub token lives ONLY here as
// a Worker secret — it is never shipped in the app.
//
// Secrets / vars (see analytics/README.md):
//   GITHUB_TOKEN  (secret)  fine-grained PAT with Issues:read+write on REPORT_REPO
//   REPORT_REPO   (var)     "owner/repo" that receives the issues
//   INGEST_KEY    (secret, optional)  if set, requests must send X-Ingest-Key

const MAX_BODY = 64 * 1024; // reject oversized payloads

export default {
  async fetch(request, env) {
    if (request.method === 'GET') return new Response('eloris-prism telemetry ingest', { status: 200 });
    if (request.method !== 'POST') return json({ error: 'method' }, 405);

    if (env.INGEST_KEY && request.headers.get('X-Ingest-Key') !== env.INGEST_KEY)
      return json({ error: 'unauthorized' }, 401);

    const raw = await request.text();
    if (raw.length > MAX_BODY) return json({ error: 'too large' }, 413);

    let d;
    try { d = JSON.parse(raw); } catch { return json({ error: 'bad json' }, 400); }

    const kind = cap(d.kind, 64) || 'unknown';
    const signature = cap(d.signature, 200);
    const build = cap(d.build, 200);
    const device = cap(d.device, 64);
    const os = cap(d.os, 32);
    const jitMode = cap(d.jitMode, 200);
    const install = cap(d.installID, 64);
    const log = cap(d.log, 30000);

    const repo = env.REPORT_REPO;
    const token = env.GITHUB_TOKEN;
    if (!repo || !token) return json({ error: 'server not configured' }, 500);

    const gh = {
      'Authorization': `Bearer ${token}`,
      'Accept': 'application/vnd.github+json',
      'User-Agent': 'eloris-prism-telemetry',
      'Content-Type': 'application/json',
      'X-GitHub-Api-Version': '2022-11-28',
    };

    // Fingerprint groups identical failures on the same build (short git hash).
    const gitHash = (build.match(/[0-9a-f]{7,40}/i) || ['nohash'])[0].slice(0, 7);
    const fp = (await sha256hex(`${kind}|${signature}|${gitHash}`)).slice(0, 10);
    const title = `[auto] ${kind}: ${signature || 'report'} · ${fp}`;

    const block =
`**Device:** \`${device}\`  **iOS:** \`${os}\`  **Build:** \`${build}\`
**JIT:** \`${jitMode || '—'}\`  **Install:** \`${install.slice(0, 8)}\`

<details><summary>Log excerpt</summary>

\`\`\`
${log}
\`\`\`
</details>`;

    // Dedup: look for an open issue carrying this fingerprint in its title.
    const q = encodeURIComponent(`repo:${repo} is:issue is:open in:title ${fp}`);
    const sres = await fetch(`https://api.github.com/search/issues?q=${q}`, { headers: gh });
    const sjson = sres.ok ? await sres.json() : { items: [] };

    if (sjson.items && sjson.items.length > 0) {
      const num = sjson.items[0].number;
      await fetch(`https://api.github.com/repos/${repo}/issues/${num}/comments`, {
        method: 'POST', headers: gh,
        body: JSON.stringify({ body: `Another occurrence:\n\n${block}` }),
      });
      return json({ ok: true, issue: num, deduped: true });
    }

    const cres = await fetch(`https://api.github.com/repos/${repo}/issues`, {
      method: 'POST', headers: gh,
      body: JSON.stringify({ title, body: block, labels: ['auto-report', kind] }),
    });
    if (!cres.ok) return json({ error: 'github', status: cres.status }, 502);
    const created = await cres.json();
    return json({ ok: true, issue: created.number });
  },
};

function cap(v, n) { return (v == null ? '' : String(v)).slice(0, n); }
function json(obj, status = 200) {
  return new Response(JSON.stringify(obj), { status, headers: { 'Content-Type': 'application/json' } });
}
async function sha256hex(s) {
  const buf = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(s));
  return [...new Uint8Array(buf)].map(b => b.toString(16).padStart(2, '0')).join('');
}
