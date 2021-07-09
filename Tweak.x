// LightsOut, by Skitty
// Toggle dark mode/night shift with the light sensor!

#import <UIKit/UIKit.h>
#import "iokit.h"
#import "UISUserInterfaceStyleMode.h"
#import "CBBlueLightClient.h"

#define BUNDLE_ID @"xyz.skitty.lightsout"

static NSMutableDictionary *settings;
static BOOL enabled;
static BOOL useDarkMode;
static BOOL useNightShift;
static int upLuxThreshold;
static int lowLuxThreshold;
static int checkInterval;

static void handleLuxChange(void *, void *, IOHIDEventQueueRef, IOHIDEventRef);

// Preference Updates
static void refreshPrefs() {
	CFArrayRef keyList = CFPreferencesCopyKeyList((CFStringRef)BUNDLE_ID, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
	if (keyList) {
		settings = (NSMutableDictionary *)CFBridgingRelease(CFPreferencesCopyMultiple(keyList, (CFStringRef)BUNDLE_ID, kCFPreferencesCurrentUser, kCFPreferencesAnyHost));
		CFRelease(keyList);
	} else {
		settings = nil;
	}
	if (!settings) {
		settings = [[NSMutableDictionary alloc] initWithContentsOfFile:[NSString stringWithFormat:@"/var/mobile/Library/Preferences/%@.plist", BUNDLE_ID]];
	}
	BOOL oldEnabled = enabled;
	int oldCheckInterval = checkInterval;

	enabled = [([settings objectForKey:@"enabled"] ?: @(YES)) boolValue];
	useDarkMode = [([settings objectForKey:@"useDarkMode"] ?: @(YES)) boolValue];
	useNightShift = [([settings objectForKey:@"useNightShift"] ?: @(NO)) boolValue];
	upLuxThreshold = [([settings objectForKey:@"upLuxThreshold"] ?: @50) intValue];
	lowLuxThreshold = [([settings objectForKey:@"lowLuxThreshold"] ?: @40) intValue];
	checkInterval = [([settings objectForKey:@"checkInterval"] ?: @3) intValue];

	if (checkInterval != oldCheckInterval) {
		stop_iokit();
		init_iokit(checkInterval);
	}
	if (enabled != oldEnabled) {
		if (enabled) start_iokit(handleLuxChange);
		else stop_iokit();
	}
}

static void PreferencesChangedCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
	refreshPrefs();
}

// Ambient Light Sensor
static void handleLuxChange(void *target, void *refcon, IOHIDEventQueueRef queue, IOHIDEventRef event) {
	if (IOHIDEventGetType(event) != kIOHIDEventTypeAmbientLightSensor) return;

	int currentLux = IOHIDEventGetIntegerValue(event, (IOHIDEventField)kIOHIDEventFieldAmbientLightSensorLevel);

	if (useDarkMode) {
		BOOL darkEnabled;
		if (@available(iOS 13, *)) { // Toggle system dark mode
			darkEnabled = ([UITraitCollection currentTraitCollection].userInterfaceStyle == UIUserInterfaceStyleDark);
			UISUserInterfaceStyleMode *styleMode = [[%c(UISUserInterfaceStyleMode) alloc] init];
			if (currentLux >= upLuxThreshold && darkEnabled) {
				styleMode.modeValue = 1;
			} else if (currentLux < lowLuxThreshold && !darkEnabled) {
				styleMode.modeValue = 2;
			}
		} else { // Toggle Dune (if installed)
			NSMutableDictionary *dunePrefs = [NSMutableDictionary dictionaryWithDictionary:[NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/com.skitty.dune.plist"]];
			if (dunePrefs && [[NSFileManager defaultManager] fileExistsAtPath:@"/var/lib/dpkg/info/com.skitty.dune.list"])
				darkEnabled = [[dunePrefs objectForKey:@"enabled"] boolValue];

			if (currentLux >= upLuxThreshold && darkEnabled) {
				CFNotificationCenterPostNotification(CFNotificationCenterGetDistributedCenter(), CFSTR("xyz.skitty.dune.disabled"), nil, nil, true);
				CFPreferencesSetAppValue((CFStringRef)@"enabled", (CFPropertyListRef)[NSNumber numberWithBool:NO], CFSTR("com.skitty.dune"));
			} else if (currentLux < lowLuxThreshold && !darkEnabled) {
				CFNotificationCenterPostNotification(CFNotificationCenterGetDistributedCenter(), CFSTR("xyz.skitty.dune.enabled"), nil, nil, true);
				CFPreferencesSetAppValue((CFStringRef)@"enabled", (CFPropertyListRef)[NSNumber numberWithBool:YES], CFSTR("com.skitty.dune"));
			}
		}
	}
	if (useNightShift) { // Toggle night shift
		Status status;
		CBBlueLightClient *nightShift = [[%c(CBBlueLightClient) alloc] init];
		[nightShift getBlueLightStatus:&status];
		BOOL shiftEnabled = status.enabled;
		if (currentLux >= upLuxThreshold && shiftEnabled) {
			[nightShift setEnabled:NO];
		} else if (currentLux < lowLuxThreshold && !shiftEnabled) {
			[nightShift setEnabled:YES];
		}
	}
}

// Tweak setup
%ctor {
	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback) PreferencesChangedCallback, (CFStringRef)[BUNDLE_ID stringByAppendingString:@".prefschanged"], NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
	refreshPrefs();

	%init;
}

%dtor {
	stop_iokit();
}
