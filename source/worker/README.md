# ELORIS-PRISM — short source URL (free)

Turns the long GitHub release URL into a short, clean SideStore source:

```
before:  https://github.com/ayanodeath/ELORIS-PRISM/releases/download/latest/source.json
after:   https://elorisprism.<your-account>.workers.dev
```

It's a tiny Cloudflare Worker that proxies + caches the `source.json` from the
rolling GitHub release. No custom domain, no cost, and it never goes stale —
every build updates the release, the Worker reflects it within 5 minutes.
The IPA/icon downloads stay on GitHub Releases, so there's no bandwidth cost.

## Deploy (one time, ~2 minutes)

1. Create a free Cloudflare account (if you don't have one).
2. Install Wrangler and log in:
   ```bash
   npm i -g wrangler
   wrangler login
   ```
3. From this folder, deploy:
   ```bash
   cd source/worker
   wrangler deploy
   ```
4. Wrangler prints the URL, e.g. `https://elorisprism.<your-account>.workers.dev`.
   The `<your-account>` part is your account's workers.dev subdomain (set it once
   in the Cloudflare dashboard → Workers & Pages → *your subdomain* if prompted).

## Use it

Add that URL as the source in SideStore. Because the app's bundle id never
changes, existing installs keep updating whether they use the short URL or the
GitHub one.

## One-tap install link (redirect)

The Worker also serves a redirect page that turns a normal `https://` link into
a one-tap "Add to SideStore":

```
https://elorisprism.<your-account>.workers.dev/install
```

Share **that** link (bio, Discord, website). On iOS it opens SideStore and
offers to add the source; it has a visible fallback button and an AltStore
alternative if the auto-redirect is blocked.

How it works: SideStore registers the URL scheme `sidestore://source?url=<feed>`.
You can't share that scheme directly (it crashes without the app installed and
browsers block custom schemes), so the `/install` page redirects to it from a
normal web page — that's the whole "redirect repo install" trick.

Routes summary:
- `/` and `/source.json` → the source feed (add this in SideStore)
- `/install` (or `/add`) → the one-tap redirect page (share this with people)

## If you later buy `elorisprism.app`

Add it as a custom domain to this same Worker (Cloudflare dashboard →
the Worker → Triggers → Custom Domains). The source URL then becomes simply
`https://elorisprism.app`. No code change needed.

## Note

If you fork/rename, update `UPSTREAM` in `worker.js` to your release URL.
