#!/usr/bin/env bash
# Move a repo checkout that landed in the wrong folder (e.g. your home) into its own folder.
#
#   scripts/relocate-source.sh <old top dir> <new dir>            # move + re-checkout, list leftovers
#   scripts/relocate-source.sh <old top dir> <new dir> --delete   # also delete the leftovers
#
# 1. Records every project path and copyfile/linkfile target from the old checkout.
# 2. Moves <old>/.repo to <new>/.repo and checks everything out again there (no download).
# 3. Lists the old copies of exactly those paths. With --delete, removes them, plus any
#    directories left empty. Nothing else in <old> is touched.
set -euo pipefail

OLD=$(realpath "${1:?old top dir}")
NEW=$(realpath -m "${2:?new dir}")
DELETE=${3:-}
LIST="$OLD/.twrp-relocate-paths.txt"
[ -f "$LIST" ] && [ ! -d "$OLD/.repo" ] && LIST_ONLY=1 || LIST_ONLY=0

if [ "$LIST_ONLY" = 0 ]; then
  [ -d "$OLD/.repo" ] || { echo "no .repo in $OLD" >&2; exit 1; }
  [ -e "$NEW/.repo" ] && { echo "$NEW/.repo already exists" >&2; exit 1; }
  cd "$OLD"
  {
    repo list -p
    repo manifest 2>/dev/null | grep -oE '<(copyfile|linkfile)[^>]*dest="[^"]+"' \
      | sed -E 's/.*dest="([^"]+)".*/\1/'
  } | sort -u > "$LIST"
  # Sanity: relative paths only.
  if grep -qE '^(/|\.\.?(/|$))|/\.\.(/|$)|^$' "$LIST"; then
    echo "unexpected path in $LIST, stopping" >&2; exit 1
  fi
  echo "==> $(wc -l < "$LIST") paths recorded in $LIST"

  echo "==> moving $OLD/.repo to $NEW/.repo"
  mkdir -p "$NEW"
  mv "$OLD/.repo" "$NEW/.repo"
  cd "$NEW"
  echo "==> checking out in $NEW (local, no download)"
  repo sync -l -j8 --force-checkout
  [ -f "$NEW/system/tools/mkbootimg/unpack_bootimg.py" ] \
    || { echo "checkout in $NEW looks incomplete; not touching $OLD" >&2; exit 1; }
  echo "==> new checkout OK"
fi

cd "$OLD"
echo
echo "Old copies in $OLD that $([ "$DELETE" = --delete ] && echo "will be" || echo "would be") deleted:"
present=0
while read -r p; do
  if [ -e "$OLD/$p" ] || [ -L "$OLD/$p" ]; then
    present=$((present + 1))
    [ "$DELETE" = --delete ] && rm -rf -- "${OLD:?}/$p" || echo "  $p"
  fi
done < "$LIST"
echo "($present paths)"

if [ "$DELETE" = --delete ]; then
  # Remove directories that only held those projects and are now empty.
  cut -d/ -f1 "$LIST" | sort -u | while read -r top; do
    [ -d "$OLD/$top" ] && find "$OLD/$top" -depth -type d -empty -delete
  done
  rm -f "$LIST"
  echo "==> cleaned up. Folders that still had your own files in them were kept."
else
  echo
  echo "Nothing was deleted. Rerun with --delete as the third argument to remove these."
fi
