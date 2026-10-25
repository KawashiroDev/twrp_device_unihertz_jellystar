# TWRP device tree for the Unihertz Jelly Star

TWRP (`twrp-14.1`) for the Unihertz Jelly Star (MT6789 / Helio G99), built for phones running
[osquera's LineageOS](https://github.com/osquera/lineageos_unihertz_jellystar). Board values
come from that tree. The kernel, dtb, dtbo and modules aren't committed; they're extracted
from the Lineage release images at build time.

> [!WARNING]
> **Untested on hardware.** It hasn't been booted on a phone yet. Keep the Lineage release
> `vendor_boot.img` you built against so you can flash it back.

## How recovery works on this phone

There is no recovery partition. Recovery is a "recovery" ramdisk fragment inside
`vendor_boot`, next to the ramdisk Android uses to boot. The build therefore produces:

| File | What it is |
|---|---|
| `vendor_boot-twrp.img` | **Use this one.** The Lineage release `vendor_boot` with only its recovery fragment replaced by TWRP. Normal boot is byte-for-byte unchanged. |
| `vendor_boot-twrp-standalone.img` | TWRP's own `vendor_boot`. Its normal-boot ramdisk is rebuilt and could differ from Lineage's. For debugging only. |

Because the image is derived from a specific Lineage release, **build against the release
installed on your phone** and rebuild after each Lineage update. An OTA also rewrites
`vendor_boot`, which puts Lineage Recovery back.

## Building

### GitHub Actions (no local resources)

1. Push this directory to a GitHub repository of your own.
2. Go to *Actions > Build TWRP > Run workflow* and enter the Lineage release tag on your phone
   (blank = latest).
3. Wait about 2–3 hours, then download the `twrp-jellystar-…` artifact.

### Locally

Needs Ubuntu/Debian with the usual Android build packages, plus `repo`, `lz4`, `cpio`, `rsync`.

- **Disk:** about 45 GB (around 25 GB shallow source, around 20 GB `out/`).
- **Memory:** 16 GB RAM + swap. On 8 GB, add 16 GB of swap first:
  `sudo fallocate -l 16G /swapfile && sudo chmod 600 /swapfile && sudo mkswap /swapfile && sudo swapon /swapfile`

Download `boot.img`, `vendor_boot.img` and `dtbo.img` from the Lineage release on your phone
into a folder, then run:

```sh
JOBS=4 ./build.sh ~/Downloads/lineage-release
```

Images land in `out-twrp/`. `SRC=` changes where the source is synced (default `~/twrp`), and
`SKIP_SYNC=1` skips `repo sync` on rebuilds.

## Flashing

```sh
adb reboot bootloader
fastboot flash vendor_boot vendor_boot-twrp.img   # current slot only
fastboot reboot recovery
```

To go back, flash the release `vendor_boot.img` the same way.

## Status

| Feature | Expected |
|---|---|
| Boot, display, touch, USB/adb | Should work: same kernel modules and USB setup as Lineage Recovery |
| Flash images, backup/restore partitions, NVRAM/NVDATA backup | Should work |
| adb sideload, Format Data, fastbootd | Should work |
| Slot switching | Should work: same AOSP boot-control HAL as Lineage Recovery |
| **Decrypting /data** | **Not built in.** It would need MediaTek's TEE-backed KeyMint from the vendor partition, and twrp-14.1's crypto code doesn't link on Android 14 sources (see `BoardConfig.mk`). Internal storage stays encrypted; use adb sideload or a microSD/OTG drive. |
| MicroSD, USB OTG | Probably; untested |

If the screen stays black but adb works, check brightness (`TW_BRIGHTNESS_PATH` in
`BoardConfig.mk`) and the pixel format (`TARGET_RECOVERY_PIXEL_FORMAT`). If it loops back to
the bootloader, collect the LK log from `expdb` the way the Lineage README describes.

## Layout

- `BoardConfig.mk`, `device.mk`, `twrp_jellystar.mk`, `AndroidProducts.mk`: device config
- `recovery/root/`: recovery fstab, `twrp.flags`, USB init
- `kernel/modules.load*`: module load lists (same as the Lineage tree)
- `scripts/prepare-prebuilts.sh`: extracts kernel/dtb/dtbo/modules from the release images
- `scripts/transplant-recovery.py`: swaps TWRP's recovery fragment into the release `vendor_boot`
- `build.sh`, `.github/workflows/build-twrp.yml`: local and CI builds
