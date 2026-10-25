#
# SPDX-FileCopyrightText: The TWRP Open Source Project
# SPDX-License-Identifier: Apache-2.0
#

$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/base.mk)

# TWRP common configuration
$(call inherit-product, vendor/twrp/config/common.mk)

# Device
$(call inherit-product, device/unihertz/jellystar/device.mk)

PRODUCT_DEVICE := jellystar
PRODUCT_NAME := twrp_jellystar
PRODUCT_BRAND := Unihertz
PRODUCT_MODEL := Jelly Star
PRODUCT_MANUFACTURER := Unihertz
PRODUCT_RELEASE_NAME := Unihertz Jelly Star

PRODUCT_GMS_CLIENTID_BASE := android-unihertz
