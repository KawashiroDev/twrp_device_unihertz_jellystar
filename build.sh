#!/usr/bin/env bash
# Build TWRP for the Unihertz Jelly Star.
#
#   ./build.sh <dir with boot.img, vendor_boot.img, dtbo.img>
#
# The images must be from exactly what's installed on the phone (stock firmware package of the
# same version, or the matching LineageOS release). The output is that vendor_boot with only
# its recovery part replaced; images from another OS/version make Android unbootable.
#
# Environment (all optional):
#   SRC=~/twrp            where the TWRP source tree is synced (~25 GB, plus ~20 GB of out/)
#   JOBS=4                parallel build jobs (about 2 GB RAM each)
#   SYNC_JOBS=4           parallel downloads; Google rate-limits (HTTP 429) above ~4
#   TWRP_BRANCH=twrp-14.1 minimal-manifest branch
#   OUTDIR=./out-twrp     where the finished images are copied
#   SKIP_SYNC=1           don't run repo sync (source already there)
#
# Output: $OUTDIR/vendor_boot-twrp.img  (recommended: your vendor_boot, TWRP recovery)
#         $OUTDIR/vendor_boot-twrp-standalone.img  (TWRP's own vendor_boot, untested)
set -euo pipefail

TREE=$(cd "$(dirname "$0")" && pwd)
IMAGES=$(realpath "${1:?usage: $0 <dir with boot.img vendor_boot.img dtbo.img>}")
SRC=${SRC:-$HOME/twrp}
JOBS=${JOBS:-4}
SYNC_JOBS=${SYNC_JOBS:-4}
TWRP_BRANCH=${TWRP_BRANCH:-twrp-14.1}
OUTDIR=$(realpath -m "${OUTDIR:-$TREE/out-twrp}")
MANIFEST=https://github.com/minimal-manifest-twrp/platform_manifest_twrp_aosp.git

for t in repo git python3 lz4 cpio rsync; do
  command -v "$t" >/dev/null || { echo "missing tool: $t" >&2; exit 1; }
done
command -v python >/dev/null || echo "WARNING: no 'python' command; some TWRP build scripts expect it (Debian/Ubuntu: sudo apt install python-is-python3)" >&2

mem_kb=$(awk '/MemTotal|SwapTotal/ {s+=$2} END {print s}' /proc/meminfo)
if [ "$mem_kb" -lt $((15 * 1024 * 1024)) ]; then
  echo "WARNING: RAM + swap is under 16 GB; the build may be OOM-killed. Add swap:" >&2
  echo "  sudo fallocate -l 16G /swapfile && sudo chmod 600 /swapfile && sudo mkswap /swapfile && sudo swapon /swapfile" >&2
fi

mkdir -p "$SRC"
cd "$SRC"
# repo searches parent directories for .repo; refuse to run inside another checkout.
parent=$(dirname "$PWD")
while [ "$parent" != / ]; do
  if [ -d "$parent/.repo" ]; then
    echo "ERROR: $parent already has a .repo (another source checkout)." >&2
    echo "repo would use that instead of $SRC. Pick a SRC outside $parent." >&2
    exit 1
  fi
  parent=$(dirname "$parent")
done
# Source patches: patches/<path_with_underscores>-*.patch applies to <path> in the source tree
# (e.g. bootable_recovery-*.patch -> bootable/recovery).
patch_dir() { local b; b=$(basename "$1"); b=${b%%-*}; echo "$SRC/${b//_//}"; }
unapply_patches() {
  for p in "$TREE"/patches/*.patch; do
    [ -f "$p" ] || continue
    d=$(patch_dir "$p")
    [ -d "$d" ] && git -C "$d" apply --reverse --check "$p" 2>/dev/null && git -C "$d" apply --reverse "$p" || true
  done
}
apply_patches() {
  for p in "$TREE"/patches/*.patch; do
    [ -f "$p" ] || continue
    d=$(patch_dir "$p")
    if git -C "$d" apply --reverse --check "$p" 2>/dev/null; then
      echo "    already applied: $(basename "$p")"
    elif git -C "$d" apply --check "$p" 2>/dev/null; then
      git -C "$d" apply "$p"; echo "    applied: $(basename "$p")"
    else
      echo "ERROR: $(basename "$p") doesn't apply to $d (TWRP source changed?)" >&2; exit 1
    fi
  done
}

if [ "${SKIP_SYNC:-0}" != 1 ]; then
  echo "==> syncing TWRP ($TWRP_BRANCH) into $SRC"
  unapply_patches
  [ -d .repo ] || repo init --depth=1 -u "$MANIFEST" -b "$TWRP_BRANCH"
  repo sync -c -j"$SYNC_JOBS" --no-tags --no-clone-bundle --optimized-fetch --prune --force-sync
fi

nested=$(find "$TREE" -mindepth 2 -name AndroidProducts.mk -not -path '*/.git/*' | head -1)
if [ -n "$nested" ]; then
  echo "ERROR: found a second copy of the tree at $(dirname "$nested")" >&2
  echo "(a zip extracted inside this folder?). Move its files up and delete it:" >&2
  echo "  rsync -a '$(dirname "$nested")/' '$TREE/' && rm -rf '$(dirname "$nested")'" >&2
  exit 1
fi

echo "==> applying source patches"
apply_patches

echo "==> installing device tree"
DEV="$SRC/device/unihertz/jellystar"
mkdir -p "$DEV"
# Paths with ':' (e.g. Windows "file:Zone.Identifier" leftovers) break make rules.
rsync -a --delete --delete-excluded --exclude .git --exclude .github --exclude out-twrp --exclude '*:*' "$TREE/" "$DEV/"

echo "==> extracting kernel, dtb, dtbo, modules from the release images"
bash "$DEV/scripts/prepare-prebuilts.sh" "$IMAGES" "$SRC/system/tools/mkbootimg"

echo "==> building vendorbootimage (this takes a while)"
set +eu
export ALLOW_MISSING_DEPENDENCIES=true
# shellcheck disable=SC1091
source build/envsetup.sh
lunch twrp_jellystar-ap2a-eng || lunch twrp_jellystar-eng
# TWRP copies recovery/root/ into $OUT/recovery/root but never removes files deleted from the
# tree since the last build, so rebuild the recovery root from scratch, including the
# timestamps that decide whether it gets repopulated (only recovery files are redone).
rm -rf "$OUT/recovery" "$OUT/obj/PACKAGING/recovery_intermediates" \
       "$OUT/obj/FAKE/twrp_ramdisk_intermediates"
# twrp-14.1's twrp_ramdisk always copies system/etc/task_profiles.json but only depends on
# it when TW_INCLUDE_CRYPTO is set, so build it first.
m task_profiles.json -j"$JOBS" || exit 1
m vendorbootimage -j"$JOBS" || exit 1
set -eu

TWRP_VB="$OUT/vendor_boot.img"
[ -f "$TWRP_VB" ] || { echo "build finished but $TWRP_VB is missing" >&2; exit 1; }

# A patched TWRP binary whose libraries aren't in the recovery image would never start (blank
# screen), so check every NEEDED library of /system/bin/recovery is present before packaging.
READELF=$(command -v readelf || command -v llvm-readelf || ls "$SRC"/prebuilts/clang/host/linux-x86/*/bin/llvm-readelf 2>/dev/null | head -1)
RROOT="$OUT/recovery/root"
if [ -n "$READELF" ] && [ -f "$RROOT/system/bin/recovery" ]; then
  missing_libs=$("$READELF" -d "$RROOT/system/bin/recovery" | sed -n 's/.*Shared library: \[\(.*\)\]/\1/p' |
    while read -r lib; do
      [ -e "$RROOT/system/lib64/$lib" ] || [ -e "$RROOT/system/lib64/bootstrap/$lib" ] || echo "$lib"
    done)
  if [ -n "$missing_libs" ]; then
    echo "ERROR: TWRP needs libraries that aren't in the recovery image:" >&2
    echo "$missing_libs" | sed 's/^/  /' >&2
    exit 1
  fi
  echo "==> recovery binary's libraries are all present"
else
  echo "WARNING: couldn't check TWRP's libraries (no readelf found)" >&2
fi

echo "==> putting TWRP's recovery fragment into the release vendor_boot"
mkdir -p "$OUTDIR"
AVBTOOL="$SRC/out/host/linux-x86/bin/avbtool"
[ -x "$AVBTOOL" ] || AVBTOOL="$SRC/external/avb/avbtool.py"
python3 "$DEV/scripts/transplant-recovery.py" \
  --base "$IMAGES/vendor_boot.img" --twrp "$TWRP_VB" \
  --out "$OUTDIR/vendor_boot-twrp.img" \
  --mkbootimg-dir "$SRC/system/tools/mkbootimg" --avbtool "$AVBTOOL"
cp "$TWRP_VB" "$OUTDIR/vendor_boot-twrp-standalone.img"
(cd "$OUTDIR" && sha256sum vendor_boot-twrp*.img > SHA256SUMS)

echo
echo "Done. Flash with:  fastboot flash vendor_boot $OUTDIR/vendor_boot-twrp.img"
