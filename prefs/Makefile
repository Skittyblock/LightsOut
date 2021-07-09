include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = LightsOut

LightsOut_FILES = $(wildcard *.m) $(wildcard SkittyPrefs/*.m) ../iokit.c
LightsOut_INSTALL_PATH = /Library/PreferenceBundles
LightsOut_PRIVATE_FRAMEWORKS = Preferences
LightsOut_CFLAGS = -fobjc-arc -I../headers
LightsOut_LDFLAGS = ../IOKit.tbd

include $(THEOS_MAKE_PATH)/bundle.mk

internal-stage::
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences$(ECHO_END)
	$(ECHO_NOTHING)cp entry.plist $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/$(BUNDLE_NAME).plist$(ECHO_END)
