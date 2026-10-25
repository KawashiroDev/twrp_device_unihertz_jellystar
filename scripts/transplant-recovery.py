#!/usr/bin/env python3
"""Put TWRP's recovery ramdisk into the LineageOS release vendor_boot.img.

The Jelly Star has no recovery partition: recovery is a ramdisk fragment (type 2,
"recovery") inside vendor_boot. Flashing TWRP's own vendor_boot would also replace the
ramdisk used for normal boot (first-stage fstab, kernel modules). This keeps the release
image exactly as it is and swaps only the recovery fragment, so Android boots the same as
before and only recovery changes.

  transplant-recovery.py --base lineage/vendor_boot.img --twrp out/.../vendor_boot.img \
      --out vendor_boot-twrp.img --mkbootimg-dir system/tools/mkbootimg [--avbtool avbtool]
"""
import argparse
import os
import shutil
import subprocess
import sys
import tempfile

RECOVERY_TYPE = "2"  # VENDOR_RAMDISK_TYPE_RECOVERY


def unpack(mkdir, image, out):
    res = subprocess.run(
        [sys.executable, os.path.join(mkdir, "unpack_bootimg.py"),
         "--boot_img", image, "--out", out, "--format", "mkbootimg", "-0"],
        check=True, capture_output=True)
    out = res.stdout.split(b"\0")
    if out and out[-1] == b"":
        out.pop()  # trailing terminator; keep other empty values like --board ""
    return [a.decode() for a in out]


def fragments(args):
    """Yield (index_of_path_arg, type, name) for each --vendor_ramdisk_fragment."""
    rtype = name = None
    for i, a in enumerate(args):
        if a == "--ramdisk_type":
            rtype = args[i + 1]
        elif a == "--ramdisk_name":
            name = args[i + 1]
        elif a == "--vendor_ramdisk_fragment":
            yield i + 1, rtype, name
            rtype = name = None


def find_recovery(args, label):
    hits = [f for f in fragments(args)
            if f[1] == RECOVERY_TYPE or (f[2] or "").lower() == "recovery"]
    if len(hits) != 1:
        found = [(t, n) for _, t, n in fragments(args)]
        sys.exit(f"{label}: expected exactly one recovery fragment, found {found}")
    return hits[0][0]


def main():
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--base", required=True, help="LineageOS release vendor_boot.img")
    p.add_argument("--twrp", required=True, help="vendor_boot.img built by TWRP")
    p.add_argument("--out", required=True)
    p.add_argument("--mkbootimg-dir", required=True)
    p.add_argument("--avbtool", help="add an AVB hash footer (recommended)")
    p.add_argument("--partition-size", type=int, default=67108864)
    o = p.parse_args()

    with tempfile.TemporaryDirectory() as tmp:
        base_dir, twrp_dir = os.path.join(tmp, "base"), os.path.join(tmp, "twrp")
        base = unpack(o.mkbootimg_dir, o.base, base_dir)
        twrp = unpack(o.mkbootimg_dir, o.twrp, twrp_dir)
        if "--vendor_boot" in base or not any(a == "--vendor_ramdisk_fragment" for a in base):
            sys.exit("base image is not a v4 vendor_boot with ramdisk fragments")

        bi, ti = find_recovery(base, "base"), find_recovery(twrp, "twrp")
        print(f"replacing {os.path.basename(base[bi])} "
              f"({os.path.getsize(base[bi])} B) with TWRP's "
              f"({os.path.getsize(twrp[ti])} B)")
        shutil.copyfile(twrp[ti], base[bi])

        out = os.path.abspath(o.out)
        subprocess.run([sys.executable, os.path.join(o.mkbootimg_dir, "mkbootimg.py"),
                        *base, "--vendor_boot", out], check=True)

    size = os.path.getsize(out)
    if size > o.partition_size:
        sys.exit(f"result is {size} B, larger than the {o.partition_size} B partition")
    if o.avbtool:
        tool = [sys.executable, o.avbtool] if o.avbtool.endswith(".py") else [o.avbtool]
        subprocess.run([*tool, "add_hash_footer", "--image", out,
                        "--partition_name", "vendor_boot",
                        "--partition_size", str(o.partition_size)], check=True)
    print(f"wrote {out}")


if __name__ == "__main__":
    main()
