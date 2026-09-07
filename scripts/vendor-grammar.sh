#!/usr/bin/env bash
# Vendor the card grammar into a consumer checkout (docs/ATTENTION.md).
#
# janus owns the record grammar — the caps in `scripts/card-grammar.json`, the
# vocabulary in `scripts/deny-list.json`, and the two gates that read them.
# Overlord and overlord-ui carry BYTE-IDENTICAL copies and pin their content
# hashes, so a cap change happens in one place and drift is a red build rather
# than a quiet divergence (L-007). Copying by hand is how the copies drifted
# before; this is that copy, done the same way every time.
#
# Usage: vendor-grammar.sh <consumer-checkout>
# Exit:  0 vendored · 1 copy failed · 64 usage
#
# What it does, and nothing else:
#   1. copies the four owned files into <consumer>/scripts/
#   2. copies the four recorded-ask fixtures into <consumer>/scripts/fixtures/
#   3. rewrites <consumer>/scripts/vendored-from-janus.sums with fresh hashes
#
# It opens no PR and commits nothing: the consumer's own session reviews the
# diff, runs its suite, and ships it. A vendoring step that pushed by itself
# would be a fleet-wide edit no repo's tests had seen.
set -uo pipefail

SRC=$(cd "$(dirname "$0")" && pwd)
DEST="${1:-}"
[ -n "$DEST" ] || { echo "usage: vendor-grammar.sh <consumer-checkout>"; exit 64; }
[ -d "$DEST" ] || { echo "no such checkout: $DEST"; exit 64; }

OWNED="card-grammar.json deny-list.json check-record.sh check-ask.sh"
FIXTURES="ask-pass.md ask-fail-hedges.md ask-fail-names-a-script.md ask-fail-subject-is-the-artifact.md"

mkdir -p "$DEST/scripts/fixtures" || exit 1

for f in $OWNED; do
  cp "$SRC/$f" "$DEST/scripts/$f" || { echo "copy failed: $f"; exit 1; }
done
for f in $FIXTURES; do
  cp "$SRC/fixtures/$f" "$DEST/scripts/fixtures/$f" || { echo "copy failed: fixtures/$f"; exit 1; }
done
chmod +x "$DEST/scripts/check-record.sh" "$DEST/scripts/check-ask.sh"

sha() { if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1"; else shasum -a 256 "$1"; fi | cut -d' ' -f1; }

REV=$(git -C "$SRC/.." rev-parse --short HEAD 2>/dev/null || echo unknown)
BRANCH=$(git -C "$SRC/.." rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)

SUMS="$DEST/scripts/vendored-from-janus.sums"
{
  echo "# Vendored from Vinylfigure/janus — these files are janus's, byte for byte."
  echo "# janus owns the record grammar: the caps in card-grammar.json, the vocabulary"
  echo "# in deny-list.json, and the two gates that read them (its docs/ATTENTION.md)."
  echo "# Overlord and overlord-ui vendor them and test equality by content hash, so a"
  echo "# fleet-wide cap or vocabulary change happens in one place and drift is a red"
  echo "# build, not a quiet divergence (L-007). Source: janus $BRANCH @ $REV."
  echo "# Re-vendor with: <janus>/scripts/vendor-grammar.sh <this checkout>"
  for f in $OWNED; do
    echo "$(sha "$DEST/scripts/$f")  scripts/$f"
  done
  for f in $FIXTURES; do
    echo "$(sha "$DEST/scripts/fixtures/$f")  scripts/fixtures/$f"
  done
} > "$SUMS" || exit 1

echo "vendored into $DEST: $(printf '%s\n' $OWNED $FIXTURES | wc -l | tr -d ' ') files, pinned in scripts/vendored-from-janus.sums"
exit 0
