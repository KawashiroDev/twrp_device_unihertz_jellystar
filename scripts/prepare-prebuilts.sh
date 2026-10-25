#!/usr/bin/env bash
# Extract the prebuilt kernel, dtb, dtbo and kernel modules TWRP needs from the LineageOS
# release images (boot.img, vendor_boot.img, dtbo.img), into this tree's kernel/ directory.
#
#   scripts/prepare-prebuilts.sh <dir with boot.img vendor_boot.img dtbo.img> <mkbootimg dir>
#
# <mkbootimg dir> is a checkout of system/tools/mkbootimg (in a TWRP source tree that's
# $SRC/system/tools/mkbootimg). Needs: python3, lz4, cpio.
set -euo pipefail

IMG_DIR=$(realpath "$1")
MKBOOTIMG_DIR=$(realpath "$2")
TREE=$(cd "$(dirname "$0")/.." && pwd)
K="$TREE/kernel"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

for f in boot.img vendor_boot.img dtbo.img; do
  [ -f "$IMG_DIR/$f" ] || { echo "missing $IMG_DIR/$f" >&2; exit 1; }
done

unpack() { python3 "$MKBOOTIMG_DIR/unpack_bootimg.py" --boot_img "$1" --out "$2" >/dev/null; }

decompress() { # decompress a ramdisk of unknown compression to stdout
  local f=$1 magic
  magic=$(od -An -tx1 -N4 "$f" | tr -d ' \n')
  case "$magic" in
    02214c18|04224d18) lz4 -dc "$f" ;;     # lz4 legacy / lz4 frame
    1f8b*)             gzip -dc "$f" ;;
    303730*)           cat "$f" ;;         # already a cpio ("070")
    *) echo "unknown ramdisk compression ($magic) in $f" >&2; return 1 ;;
  esac
}

rm -rf "$K/dtb" "$K/modules" "$K/Image.lz4" "$K/dtbo.img"
mkdir -p "$K/dtb" "$K/modules"

echo "==> kernel from boot.img"
unpack "$IMG_DIR/boot.img" "$WORK/boot"
cp "$WORK/boot/kernel" "$K/Image.lz4"

echo "==> dtb + modules from vendor_boot.img"
unpack "$IMG_DIR/vendor_boot.img" "$WORK/vb"
cp "$WORK/vb/dtb" "$K/dtb/jellystar.dtb"     # exactly one .dtb — see BoardConfig.mk

mkdir -p "$WORK/rd"
for frag in "$WORK"/vb/vendor_ramdisk*; do
  [ -f "$frag" ] || continue
  ( cd "$WORK/rd" && decompress "$frag" | cpio -idm --quiet --no-absolute-filenames 2>/dev/null ) || true
done
find "$WORK/rd" -name '*.ko' -exec cp -f -t "$K/modules/" {} +

echo "==> dtbo.img"
cp "$IMG_DIR/dtbo.img" "$K/dtbo.img"

missing=$(cat "$K/modules.load.ramdisk" "$K/modules.load.recovery" | sort -u | while read -r m; do
  [ -n "$m" ] && [ ! -f "$K/modules/$m" ] && echo "$m"; done || true)
if [ -n "$missing" ]; then
  echo "$(echo "$missing" | wc -l) modules listed in kernel/modules.load.* are not in vendor_boot, e.g.:" >&2
  echo "$missing" | head -5 | sed 's/^/  /' >&2
  exit 1
fi

echo "OK: $(ls "$K/modules" | wc -l) modules, kernel $(stat -c%s "$K/Image.lz4") bytes"
