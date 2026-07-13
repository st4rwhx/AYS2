# SideStore Community-Source submission — ELORIS-PRISM

Ready-to-post material for a Pull Request to
[SideStore/Community-Source](https://github.com/SideStore/Community-Source)
(gets ELORIS-PRISM into "SideStore Team Picks").

> Post the PR from the account that owns the source repo. Attach the checklist
> items below. Screenshots must be added once the Frutiger Aero redesign ships.

---

## PR title

Add ELORIS-PRISM (PlayStation 2 emulator for iPhone & iPad)

## PR description (paste this)

**App:** ELORIS-PRISM — a PlayStation 2 emulator for iOS.

**What it does:** Loads the user's own PS2 BIOS dump and disc images
(.iso / .bin / .chd / .img) and plays them with a JIT recompiler. Save states,
on-screen controls, per-game fixes. Open source (GPL-3.0), built on the
PCSX2 lineage.

**Goals:** A polished, community-driven PS2 experience on iOS with a focus on
UX and a frictionless setup.

**Origin:** This is my own app/fork.

**Category:** games

**Not pirated:** ships no BIOS and no games; the user supplies their own dumps.

**Source URL:** `https://elorisprism.<account>.workers.dev`
(short proxy of the GitHub release `source.json`; downloads are on GitHub Releases)

**Bundle id:** `com.balaj.elorisprism`

**Entitlements:** the app uses no special entitlements beyond standard sandbox
(file access for imported ISO/BIOS via the Files app). No network entitlement
for JIT (JIT is enabled externally by the user via a JIT enabler / LocalDevVPN).

**Integrity:** every release publishes `checksums.txt` (md5 + sha256 of the IPA)
next to the IPA. The md5 of the current build is in that file.

---

## Submission checklist (SideStore requirements)

- [x] Icon — `icon-1024.png`, published each release.
- [ ] **Device screenshots** — add after the Frutiger Aero redesign lands.
- [x] Version changes inside the app (`0.1.<run>` per build, shown in Settings/OSD).
- [x] Own CDN — GitHub Releases (rolling `latest` tag).
- [x] Category specified (`games`).
- [x] **md5 hash** for the download — in `checksums.txt` on every release.
- [x] Content policy — no adult/pirated/malware content.

## What's still needed before posting

1. Deploy the free source Worker (see `source/worker/README.md`) → get the short URL.
2. Take clean screenshots of the redesigned (Aero) app and add their URLs to
   `source.json` `screenshotURLs` (publish them as release assets).
3. Then open the PR above.
