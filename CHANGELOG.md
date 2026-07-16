# Changelog

AYS2 ships as a **rolling release**: every green build publishes
`AYS2-0.1.<build>.ipa` to the
[rolling release](https://github.com/st4rwhx/AYS2/releases/tag/latest), and the
SideStore/AltStore feed (`source.json`) always points at the newest one. The
version you see in the app (About screen) and in SideStore is that same
`0.1.<build>` number — one number, everywhere.

## 0.1.184+ — 2026-07-16 — ARMSX2 iOS 2.4.0 core

- **Core upgraded to ARMSX2 iOSv2.4.0** (from 2.2.2): native ARM64 recompiler
  progress (aR5900), NEON audio path, Metal renderer optimizations, rebuilt
  upstream pause menu and per-game settings, RetroAchievements sounds, DEV9
  DNS fallback.
- Rebrand completed on the new core: AYS2 name everywhere (in-game OSD, About,
  fullscreen UI, welcome sheet), bundle id `com.ayano.aysx2`.
- Fixed a Swift 6 actor-isolation compile error reintroduced by upstream 2.4.0.
- JIT default remains `legacy` (brk #0x69 / StikDebug handshake) — the protocol
  that actually boots on modern iOS sideload setups.
- Version cleanup: the rolling release is now the repo's official *Latest
  release*; the empty semantic-release ghosts (v0.1.0–v0.1.2) and their
  workflow were removed.

## 0.1.147–0.1.159 — 2026-07-15/16 — AYS2 rebrand era

- ELORIS-PRISM renamed to AYS2 (`com.ayano.aysx2`), releases moved to
  `st4rwhx/AYS2`, Cloudflare Worker one-tap install page. Core: ARMSX2 2.2.2.

## Earlier — ELORIS-PRISM era

- NXE-style dashboard with 3D cover carousel, app-wide light/dark theme,
  community welcome (Discord/GitHub), tile pause menu, L1/R1 bumpers,
  SideStore versioned-IPA distribution, JIT legacy default fix.
