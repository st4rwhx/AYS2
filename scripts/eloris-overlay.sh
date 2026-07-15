#!/usr/bin/env bash
# eloris-overlay.sh — the AYS2 overlay tool.
#
# Makes the "ride on top of ARMSX2 without breaking our stuff" pattern operational.
# See docs/ELORIS_OVERLAY.md for the full contract.
#
#   ./scripts/eloris-overlay.sh seams        # every AYS2 seam (marked edits)
#   ./scripts/eloris-overlay.sh additive     # our files upstream never has
#   ./scripts/eloris-overlay.sh diff <UPSTREAM>   # core parity vs an ARMSX2 checkout
#
# <UPSTREAM> is a path to an ARMSX2 working tree (its app/src/main/{cpp,swift}).

set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

cmd="${1:-help}"

case "$cmd" in
  seams)
    echo "== AYS2 seams (marked edits inside upstream files) =="
    grep -rn "AYS2:" src/ .github/ 2>/dev/null || echo "(none found)"
    echo
    echo "Seam files:"
    grep -rl "AYS2:" src/ .github/ 2>/dev/null | sort
    ;;

  additive)
    echo "== AYS2 additive files (100% ours) =="
    for f in \
      src/swift/Views/DashboardView.swift \
      src/swift/Views/RetroKit.swift \
      src/swift/Views/CommunityView.swift \
      src/swift/Views/DiscordLogoShape.swift \
      src/swift/Models/SoundManager.swift \
      src/swift/Views/TermsOfUseView.swift ; do
      [ -f "$f" ] && echo "  OK   $f" || echo "  MISSING $f"
    done
    ;;

  diff)
    up="${2:?usage: eloris-overlay.sh diff <UPSTREAM_TREE>}"
    ucpp="$up/app/src/main/cpp"
    [ -d "$ucpp" ] || ucpp="$up/cpp"
    echo "== Core parity: src/cpp/{pcsx2,common} vs $ucpp =="
    echo "(files that differ should be ONLY our marked seams — everything else must match upstream)"
    for d in pcsx2 common; do
      diff -rq "src/cpp/$d" "$ucpp/$d" 2>/dev/null \
        | grep -vE 'Only in src/cpp' \
        | sed "s#$ucpp/##; s#src/cpp/##" || true
    done
    echo
    echo "Any differing file NOT carrying an AYS2 marker is drift — investigate."
    ;;

  *)
    sed -n '2,16p' "$0"
    ;;
esac
