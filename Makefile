INSTALL_TARGET_PROCESSES = SpringBoard

export TARGET = iphone:clang::11.0
export ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = LightsOut

LightsOut_FILES = Tweak.x
LightsOut_CFLAGS = -fobjc-arc -Iheaders
LightsOut_LDFLAGS = ./IOKit.tbd

include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += prefs
include $(THEOS_MAKE_PATH)/aggregate.mk
