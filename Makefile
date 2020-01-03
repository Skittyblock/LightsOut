INSTALL_TARGET_PROCESSES = SpringBoard
ARCHS = arm64 arm64e
TARGET = iphone:clang::11.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = LightsOut

LightsOut_FILES = Tweak.xm
LightsOut_CFLAGS = -fobjc-arc -Iheaders
LightsOut_LDFLAGS = ./IOKit.tbd

include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += prefs
include $(THEOS_MAKE_PATH)/aggregate.mk
