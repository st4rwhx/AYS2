# AYS2 — short source URL (free)

Turns the long GitHub release URL into a short, clean SideStore/AltStore source:

```
before:  https://github.com/st4rwhx/AYS2/releases/download/latest/source.json
after:   https://aysx2.<your-account>.workers.dev
```

It's a tiny Cloudflare Worker that proxies + caches the `source.json` from the
rolling GitHub release. No custom domain, no cost, and it never goes stale —
every build updates the release, the Worker reflects it within 5 minutes.
The IPA/icon downloads stay on GitHub Releases, so there's no bandwidth cost.

## Features

- **One-tap install link**: Share `https://aysx2.<your-account>.workers.dev/install`
  and iOS users get a single tap to add AYS2 to SideStore.
- **Zero bandwidth cost**: The Worker only proxies the tiny JSON feed (~2KB);
  the IPA is served by GitHub Releases.
- **Always fresh**: Cache expires every 5 minutes, so new builds show up immediately.
- **Automatic fallback**: Works with both SideStore and AltStore.

## Deploy (one time, ~2 minutes)

### 1. Create a Cloudflare account (if you don't have one)
   - Go to [cloudflare.com](https://cloudflare.com) and sign up (free).

### 2. Install Wrangler
   ```bash
   npm install -g @cloudflare/wrangler
   ```
   Or if you use macOS with Homebrew:
   ```bash
   brew install wrangler
   ```

### 3. Log in
   ```bash
   wrangler login
   ```
   This opens a browser to authenticate.

### 4. Deploy the Worker
   From this folder:
   ```bash
   cd source/worker
   wrangler deploy
   ```

   Wrangler prints your Worker URL, e.g.:
   ```
   Deployed to https://aysx2.<your-account>.workers.dev
   ```

## Use it

### Add as a SideStore source
In the SideStore app:
1. Tap "Browse" → "Add Source"
2. Paste: `https://aysx2.<your-account>.workers.dev`
3. Tap "Add" → AYS2 appears, tap "Get" to install

### Share a one-tap link
Share this URL (on Discord, your website, bio, etc.):
```
https://aysx2.<your-account>.workers.dev/install
```

On iOS, tapping it opens SideStore and immediately offers to add the source.
(If the app scheme isn't registered, a visible fallback button appears.)

## Routes

- `/` and `/source.json` → the SideStore/AltStore source feed
- `/install` (or `/add`) → the one-tap redirect page (share this)
- `/status` → health check (returns JSON)

## Custom domain (optional)

If you buy `aysx2.app` or use an existing domain:
1. In the Cloudflare dashboard, go to the Worker
2. Click **Triggers** → **Custom Domains**
3. Add your domain (e.g., `aysx2.app` or `install.example.com`)

The source URL then becomes simply `https://aysx2.app` — no code change needed.

## Update the upstream URL (if you fork)

Edit `UPSTREAM` in `worker.js` to point to your release:
```javascript
const UPSTREAM = "https://github.com/your-name/your-fork/releases/download/latest/source.json";
```
Then redeploy:
```bash
wrangler deploy
```

## Troubleshooting

### "Workers feature not available"
Free Cloudflare accounts have Workers enabled by default. If you see this error,
check that you're logged in with the right email:
```bash
wrangler whoami
```

### "Failed to publish your Worker"
Make sure you're in the `source/worker` folder:
```bash
pwd
# → should end with "source/worker"
wrangler deploy
```

### SideStore says "source invalid"
The `source.json` file from GitHub Releases might have formatting issues.
Check that it's valid JSON:
```bash
curl https://github.com/st4rwhx/AYS2/releases/download/latest/source.json | jq
```

