#!/usr/bin/env bash
# Reassemble a split image from parts using the manifest, with checksum verification.
# Usage: ./join_img.sh /path/to/<stem>_parts/<stem>.manifest.txt [output.img]

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 /path/to/<stem>_parts/<stem>.manifest.txt [output.img]" >&2
  exit 1
fi

MANIFEST="$(readlink -f "$1")"
OUT_IMG="${2:-reassembled.img}"
[[ -f "$MANIFEST" ]] || { echo "Error: manifest not found: $MANIFEST" >&2; exit 1; }

DIR="$(dirname "$MANIFEST")"

# checksum tool
if command -v sha256sum >/dev/null 2>&1; then
  SUMCMD="sha256sum"
elif command -v shasum >/dev/null 2>&1; then
  SUMCMD="shasum -a 256"
else
  echo "Error: need sha256sum or shasum" >&2
  exit 1
fi

# parse manifest
FORMAT=$(grep -E '^FORMAT=' "$MANIFEST" | cut -d= -f2-)
[[ "$FORMAT" == "img-split-v1" ]] || { echo "Error: unsupported manifest format: $FORMAT" >&2; exit 1; }
ORIG_FILE=$(grep -E '^ORIGINAL_FILE=' "$MANIFEST" | cut -d= -f2-)
ORIG_SIZE=$(grep -E '^ORIGINAL_SIZE=' "$MANIFEST" | cut -d= -f2-)
ORIG_SHA=$(grep -E '^ORIGINAL_SHA256=' "$MANIFEST" | cut -d= -f2-)
PREFIX=$(grep -E '^PART_PREFIX=' "$MANIFEST" | cut -d= -f2-)

mapfile -t PART_LINES < <(awk '/^PARTS_BEGIN/{flag=1;next}/^PARTS_END/{flag=0}flag' "$MANIFEST")
if [[ ${#PART_LINES[@]} -eq 0 ]]; then
  echo "Error: no parts listed in manifest" >&2
  exit 1
fi

echo "[*] Verifying parts..."
MISSING=0
for line in "${PART_LINES[@]}"; do
  part=$(awk '{print $1}' <<<"$line")
  sha=$(awk '{print $2}' <<<"$line")
  path="${DIR}/${part}"
  if [[ ! -f "$path" ]]; then
    echo "Missing: $part"
    MISSING=1
    continue
  fi
  calc=$($SUMCMD "$path" | awk '{print $1}')
  if [[ "$calc" != "$sha" ]]; then
    echo "Checksum mismatch: $part"
    echo " expected: $sha"
    echo "   actual: $calc"
    exit 1
  fi
done
[[ $MISSING -eq 0 ]] || { echo "Error: missing parts. Aborting." >&2; exit 1; }

echo "[*] Concatenating parts into $OUT_IMG ..."
: > "$OUT_IMG"
# sort numerically by suffix, supports both ...part001 and ...partaa if used
printf '%s\n' "${PART_LINES[@]}" \
 | awk '{print $1}' \
 | sort -V \
 | while read -r p; do
     cat "${DIR}/${p}" >> "$OUT_IMG"
   done

echo "[*] Verifying final image checksum and size..."
FINAL_SHA=$($SUMCMD "$OUT_IMG" | awk '{print $1}')
FINAL_SIZE=$(stat -c%s "$OUT_IMG" 2>/dev/null || stat -f%z "$OUT_IMG")

if [[ "$FINAL_SHA" != "$ORIG_SHA" ]]; then
  echo "Error: final SHA-256 mismatch"
  echo " expected: $ORIG_SHA"
  echo "   actual: $FINAL_SHA"
  exit 1
fi

if [[ -n "${ORIG_SIZE:-}" && "$FINAL_SIZE" != "$ORIG_SIZE" ]]; then
  echo "Warning: size mismatch"
  echo " manifest: $ORIG_SIZE"
  echo "   actual: $FINAL_SIZE"
else
  echo "[✓] Reassembled image verified."
fi

echo "Output image: $(readlink -f "$OUT_IMG")"
