#
# SPDX-FileCopyrightText: The TWRP Open Source Project
# SPDX-License-Identifier: Apache-2.0
#
# Values below are copied from osquera/lineageos_unihertz_jellystar (BoardConfig.mk), which
# verified them against the stock boot/vendor_boot headers and scatter file. The kernel,
# dtb, dtbo and modules are not committed: scripts/prepare-prebuilts.sh extracts them from
# the Lineage release's boot.img / vendor_boot.img / dtbo.img.

DEVICE_PATH := device/unihertz/jellystar

# Build hacks commonly needed for TWRP minimal-manifest builds
ALLOW_MISSING_DEPENDENCIES := true
BUILD_BROKEN_DUP_RULES := true
BUILD_BROKEN_ELF_PREBUILT_PRODUCT_COPY_FILES := true
BUILD_BROKEN_MISSING_REQUIRED_MODULES := true

# Architecture (Helio G99: 2x A76 + 6x A55)
TARGET_ARCH := arm64
TARGET_ARCH_VARIANT := armv8-2a
TARGET_CPU_ABI := arm64-v8a
TARGET_CPU_ABI2 :=
TARGET_CPU_VARIANT := generic
TARGET_CPU_VARIANT_RUNTIME := cortex-a76

TARGET_2ND_ARCH := arm
TARGET_2ND_ARCH_VARIANT := armv8-2a
TARGET_2ND_CPU_ABI := armeabi-v7a
TARGET_2ND_CPU_ABI2 := armeabi
TARGET_2ND_CPU_VARIANT := generic
TARGET_2ND_CPU_VARIANT_RUNTIME := cortex-a55

# Platform
TARGET_BOARD_PLATFORM := mt6789
TARGET_BOOTLOADER_BOARD_NAME := g58v89c2k_dfl_eea
TARGET_NO_BOOTLOADER := true
TARGET_USES_UEFI := false

# A/B
AB_OTA_UPDATER := true
AB_OTA_PARTITIONS += \
    boot \
    vendor_boot \
    dtbo \
    system \
    system_ext \
    product \
    vendor \
    vendor_dlkm \
    odm_dlkm \
    system_dlkm \
    vbmeta \
    vbmeta_system \
    vbmeta_vendor

# Kernel / boot image header (v4, GKI)
BOARD_KERNEL_BASE := 0x3fff8000
BOARD_KERNEL_OFFSET := 0x00008000
BOARD_KERNEL_PAGESIZE := 4096
BOARD_KERNEL_TAGS_OFFSET := 0x07c88000
BOARD_RAMDISK_OFFSET := 0x26f08000
BOARD_DTB_OFFSET := 0x07c88000
BOARD_BOOT_HEADER_VERSION := 4
BOARD_INCLUDE_DTB_IN_BOOTIMG := true
BOARD_KERNEL_IMAGE_NAME := Image.lz4
BOARD_KERNEL_SEPARATED_DTBO := true

BOARD_KERNEL_CMDLINE := bootopt=64S3,32N2,64N2
BOARD_BOOTCONFIG := kernel.rcu_nocbs=all
BOARD_BOOTCONFIG += kernel.rcutree.enable_rcu_lazy=1
BOARD_BOOTCONFIG += kernel.rcupdate.rcu_cpu_stall_cputime=1

BOARD_MKBOOTIMG_ARGS := --ramdisk_offset $(BOARD_RAMDISK_OFFSET)
BOARD_MKBOOTIMG_ARGS += --tags_offset $(BOARD_KERNEL_TAGS_OFFSET)
BOARD_MKBOOTIMG_ARGS += --dtb_offset $(BOARD_DTB_OFFSET)
BOARD_MKBOOTIMG_ARGS += --header_version $(BOARD_BOOT_HEADER_VERSION)
BOARD_MKBOOTIMG_ARGS += --board ""

TARGET_PREBUILT_KERNEL := $(DEVICE_PATH)/kernel/Image.lz4
TARGET_KERNEL_ARCH := arm64
BOARD_PREBUILT_DTBIMAGE_DIR := $(DEVICE_PATH)/kernel/dtb
BOARD_PREBUILT_DTBOIMAGE := $(DEVICE_PATH)/kernel/dtbo.img

# Kernel modules (taken from the release vendor_boot by prepare-prebuilts.sh)
BOARD_VENDOR_RAMDISK_KERNEL_MODULES_LOAD := $(strip $(shell cat $(DEVICE_PATH)/kernel/modules.load.ramdisk 2>/dev/null))
BOARD_VENDOR_RAMDISK_RECOVERY_KERNEL_MODULES_LOAD := $(strip $(shell cat $(DEVICE_PATH)/kernel/modules.load.recovery 2>/dev/null))
BOARD_VENDOR_RAMDISK_KERNEL_MODULES := $(foreach m,$(sort $(BOARD_VENDOR_RAMDISK_KERNEL_MODULES_LOAD) $(BOARD_VENDOR_RAMDISK_RECOVERY_KERNEL_MODULES_LOAD)),$(DEVICE_PATH)/kernel/modules/$(m))
BOARD_VENDOR_RAMDISK_RECOVERY_KERNEL_MODULES := $(foreach m,$(BOARD_VENDOR_RAMDISK_RECOVERY_KERNEL_MODULES_LOAD),$(DEVICE_PATH)/kernel/modules/$(m))
BOARD_DO_NOT_STRIP_VENDOR_RAMDISK_MODULES := true
BOARD_DO_NOT_STRIP_RECOVERY_MODULES := true

# Partitions (sizes match MT6789_Android_scatter.txt)
BOARD_FLASH_BLOCK_SIZE := 131072
BOARD_BOOTIMAGE_PARTITION_SIZE := 67108864
BOARD_VENDOR_BOOTIMAGE_PARTITION_SIZE := 67108864
BOARD_DTBOIMG_PARTITION_SIZE := 8388608
BOARD_SUPER_PARTITION_SIZE := 9663676416
BOARD_SUPER_PARTITION_GROUPS := mediatek_dynamic_partitions
BOARD_MEDIATEK_DYNAMIC_PARTITIONS_PARTITION_LIST := odm_dlkm product system system_dlkm system_ext vendor vendor_dlkm
BOARD_MEDIATEK_DYNAMIC_PARTITIONS_SIZE := 9661579264
BOARD_USES_METADATA_PARTITION := true

BOARD_SYSTEMIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_SYSTEM_EXTIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_PRODUCTIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE := erofs
BOARD_VENDOR_DLKMIMAGE_FILE_SYSTEM_TYPE := erofs
BOARD_ODM_DLKMIMAGE_FILE_SYSTEM_TYPE := erofs
BOARD_SYSTEM_DLKMIMAGE_FILE_SYSTEM_TYPE := erofs
BOARD_USERDATAIMAGE_FILE_SYSTEM_TYPE := f2fs
TARGET_USERIMAGES_USE_EXT4 := true
TARGET_USERIMAGES_USE_F2FS := true

TARGET_COPY_OUT_PRODUCT := product
TARGET_COPY_OUT_SYSTEM_EXT := system_ext
TARGET_COPY_OUT_VENDOR := vendor
TARGET_COPY_OUT_VENDOR_DLKM := vendor_dlkm
TARGET_COPY_OUT_ODM_DLKM := odm_dlkm
TARGET_COPY_OUT_SYSTEM_DLKM := system_dlkm

# Recovery lives in vendor_boot. Unihertz's LK needs a separate "recovery" ramdisk fragment
# (type 0x2) or it asserts in boot_info.c and loops (found by the Lineage tree).
BOARD_MOVE_RECOVERY_RESOURCES_TO_VENDOR_BOOT := true
BOARD_INCLUDE_RECOVERY_RAMDISK_IN_VENDOR_BOOT := true
TARGET_RECOVERY_FSTAB := $(DEVICE_PATH)/recovery/root/system/etc/recovery.fstab
TARGET_RECOVERY_PIXEL_FORMAT := BGRA_8888
TARGET_USES_MKE2FS := true
BOARD_RAMDISK_USE_LZ4 := true

# Spoofed high version/patch level so KeyMint never refuses recovery for rollback
PLATFORM_SECURITY_PATCH := 2099-12-31
VENDOR_SECURITY_PATCH := 2099-12-31
PLATFORM_VERSION := 99.87.36
PLATFORM_VERSION_LAST_STABLE := $(PLATFORM_VERSION)
BOOT_SECURITY_PATCH := 2026-05-01

# AVB — same test key and disabled-verification vbmeta as the Lineage build
BOARD_AVB_ENABLE := true
BOARD_AVB_MAKE_VBMETA_IMAGE_ARGS += --flags 3

# --- TWRP ---
TW_THEME := portrait_mdpi
TARGET_SCREEN_WIDTH := 480
TARGET_SCREEN_HEIGHT := 854
TARGET_SCREEN_DENSITY := 220
TW_FRAMERATE := 60
TW_BRIGHTNESS_PATH := "/sys/class/leds/lcd-backlight/brightness"
TW_EXTRA_LANGUAGES := false
TW_SCREEN_BLANK_ON_BOOT := true
TW_INPUT_BLACKLIST := "hbtp_vm"
TW_DEVICE_VERSION := jellystar

TW_USE_TOOLBOX := true
TW_INCLUDE_REPACKTOOLS := true
TW_INCLUDE_RESETPROP := true
TW_INCLUDE_LPDUMP := true
TW_INCLUDE_LPTOOLS := true
TW_INCLUDE_FASTBOOTD := true
TW_EXCLUDE_APEX := true
TW_LOAD_VENDOR_BOOT_MODULES := true
TW_BACKUP_EXCLUSIONS := /data/fonts

# Decryption: off. It would need MediaTek's TEE-backed KeyMint from the vendor partition,
# which isn't wired up, and twrp-14.1's crypto path doesn't even link: libtar asks for the
# Android 12 names *-ndk_platform (android.security.apc-ndk_platform etc.), which Android 13+
# renamed to *-ndk. /data stays encrypted; Format Data, sideload and partition backups work.
# TW_INCLUDE_CRYPTO := true
# TW_INCLUDE_CRYPTO_FBE := true
# TW_INCLUDE_FBE_METADATA_DECRYPT := true
# TW_USE_FSCRYPT_POLICY := 2

# Debug
TARGET_USES_LOGD := true
TWRP_INCLUDE_LOGCAT := true
