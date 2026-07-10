# ELORIS-PRISM — Anonymous diagnostics

When the app crashes or hits a fatal error, it sends an **anonymous** report so
bugs can be found and fixed. No account, no personal data — a random install
UUID, the device model, the iOS version, the build id, and a capped technical
log excerpt. Users are told on first launch and can turn it off any time in
**Settings → Anonymous Diagnostics**.

## How it flows

```
app  ──POST JSON──▶  Cloudflare Worker  ──GitHub API──▶  GitHub issues
(only knows a URL)   (holds the token)                   (you + Claude read them)
```

The app ships **only the Worker URL** — never a GitHub token. The token lives as
a Worker secret, so it can't be extracted from the distributed app.

## What the app collects

Built in `src/swift/Models/TelemetryManager.swift`. On launch it reads the
previous session's preserved log (`pcsx2_log.prev.txt`, saved by `ios_main.mm`
before the new log truncates it) and, **only if** it contains a crash
(`SIGSEGV/SIGBUS/SIGILL/SIGABRT` + backtrace) or a known fatal error
(JIT/VM allocation failure), uploads:

| field | example |
|-------|---------|
| `kind` | `crash-sigsegv`, `jit-txm-fail`, `vm-alloc-fail` |
| `signature` | the matched marker |
| `build` | `@@BUILD_ID@@ 897d11c_Jul 10 2026` |
| `device` | `iPhone15,4` |
| `os` | `26.3` |
| `jitMode` | `@@JIT_MODE@@ mode=LuckTXM (1)` |
| `installID` | random UUID (first 8 chars kept in the issue) |
| `log` | last ~250 lines, capped at 24 KB |

## Deploy the Worker (~5 min)

1. **Create a report repo** (private is fine) that will receive the issues.
2. **Create a fine-grained PAT** (github.com → Settings → Developer settings →
   Fine-grained tokens) scoped to *only* that repo, with **Issues: Read and
   write**. Copy it.
3. Install Wrangler and deploy:
   ```bash
   npm i -g wrangler
   cd analytics/worker
   wrangler login
   wrangler secret put GITHUB_TOKEN      # paste the PAT
   wrangler deploy
   ```
   `wrangler.toml` sets `REPORT_REPO`. Optionally also
   `wrangler secret put INGEST_KEY` and set the same value in the app to reject
   junk POSTs.
4. Copy the deployed URL (e.g. `https://eloris-telemetry.<you>.workers.dev`).
5. Put it in the app: set `TelemetryManager.endpointString` in
   `src/swift/Models/TelemetryManager.swift`. While it's empty the uploader is a
   safe no-op, so nothing is sent until you deploy.

## Privacy notes

- Reports are only sent for crashes / fatal errors, not normal use.
- No gameplay, no filenames beyond the disc serial in logs, no account.
- Default on, with a first-run notice and a Settings opt-out (GDPR-friendly
  baseline). Set the default to off in `TelemetryManager.isEnabled` if you'd
  rather make it strictly opt-in.
