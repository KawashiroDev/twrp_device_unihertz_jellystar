#
# SPDX-FileCopyrightText: The TWRP Open Source Project
# SPDX-License-Identifier: Apache-2.0
#
# TWRP device config for the Unihertz Jelly Star (MT6789 / Helio G99).
# Derived from osquera/lineageos_unihertz_jellystar; only the parts recovery needs.

LOCAL_PATH := device/unihertz/jellystar

# Shipped with Android 13 (ro.product.first_api_level=33)
PRODUCT_SHIPPING_API_LEVEL := 33

# Virtual A/B, recovery in vendor_boot (same as the Lineage tree)
$(call inherit-product, $(SRC_TARGET_DIR)/product/virtual_ab_ota/launch_with_vendor_ramdisk.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/emulated_storage.mk)

# Dynamic partitions
PRODUCT_USE_DYNAMIC_PARTITIONS := true

# Boot control: the Lineage tree uses AOSP's misc-based HAL on this device, so TWRP can too.
PRODUCT_PACKAGES += \
    android.hardware.boot-service.default_recovery

PRODUCT_PACKAGES += \
    fastbootd \
    update_engine_sideload

# First-stage fstab in the vendor ramdisk. Only matters if you flash TWRP's own vendor_boot
# image directly; the recommended "transplanted" image keeps Lineage's untouched.
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/recovery/fstab.mt6789:$(TARGET_COPY_OUT_VENDOR_RAMDISK)/first_stage_ramdisk/fstab.mt6789

# libprocessgroup (used by logd, servicemanager, ...) reads /etc/task_profiles.json, and the
# stock vendor's task_profiles.json aggregates profiles defined there. twrp-14.1 only installs it
# as task_profiles/task_profiles_30.json, so logd and servicemanager aborted in a restart loop and
# zip installs hung on servicemanager.ready (seen on device).
PRODUCT_COPY_FILES += \
    system/core/libprocessgroup/profiles/task_profiles.json:$(TARGET_COPY_OUT_RECOVERY)/root/system/etc/task_profiles.json

# Soong
PRODUCT_SOONG_NAMESPACES += \
    $(LOCAL_PATH)
