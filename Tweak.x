// LightsOut, by Skitty
// Toggle dark mode/night shift with the light sensor!

#import <UIKit/UIKit.h>
#import <IOKit/hid/IOHIDEventSystem.h>
#import <IOKit/hid/IOHIDEventSystemClient.h>
#import "UISUserInterfaceStyleMode.h"
#import "CBBlueLightClient.h"

int IOHIDEventSystemClientSetMatching(IOHIDEventSystemClientRef client, CFDictionaryRef match);
CFArrayRef IOHIDEventSystemClientCopyServices(IOHIDEventSystemClientRef);
IOHIDEventSystemClientRef IOHIDEventSystemClientCreate(CFAllocatorRef allocator);
typedef struct __IOHIDServiceClient *IOHIDServiceClientRef;
int IOHIDServiceClientSetProperty(IOHIDServiceClientRef, CFStringRef, CFNumberRef);
CFNotificationCenterRef CFNotificationCenterGetDistributedCenter(void);

#define BUNDLE_ID @"xyz.skitty.lightsout"

void init_iokit();
void start_iokit();
void stop_iokit();

static IOHIDEventSystemClientRef ioHIDClient;
static CFRunLoopRef ioHIDRunLoopSchedule;

static NSMutableDictionary *settings;
static BOOL enabled;
static BOOL useDarkMode;
static BOOL useNightShift;
static int upluxThreshold;
static int lowluxThreshold;
static int checkInterval;

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
	upluxThreshold = [([settings objectForKey:@"upluxThreshold"] ?: @50) intValue];
	lowluxThreshold = [([settings objectForKey:@"lowluxThreshold"] ?: @40) intValue];
	checkInterval = [([settings objectForKey:@"checkInterval"] ?: @3) intValue];

	if (checkInterval != oldCheckInterval) {
		stop_iokit();
		init_iokit();
	}
	if (enabled != oldEnabled) {
		if (enabled)
			start_iokit();
		else
			stop_iokit();
	}
}

static void PreferencesChangedCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
	refreshPrefs();
}

// Ambient Light Sensor
void handle_event(void* target, void *refcon, IOHIDEventQueueRef queue, IOHIDEventRef event) {
	if (IOHIDEventGetType(event) == kIOHIDEventTypeAmbientLightSensor) {
		int currentLux = IOHIDEventGetIntegerValue(event, (IOHIDEventField)kIOHIDEventFieldAmbientLightSensorLevel);

		if (useDarkMode) {
			BOOL darkEnabled;
			if (@available(iOS 13, *)) { // Toggle system dark mode
				darkEnabled = ([UITraitCollection currentTraitCollection].userInterfaceStyle == UIUserInterfaceStyleDark);
				UISUserInterfaceStyleMode *styleMode = [[%c(UISUserInterfaceStyleMode) alloc] init];
				if (currentLux >= lowluxThreshold && darkEnabled) {
					styleMode.modeValue = 1;
				} else if (currentLux < upluxThreshold && !darkEnabled) {
					styleMode.modeValue = 2;
				}
			} else { // Toggle Dune (if installed)
				NSMutableDictionary *dunePrefs = [NSMutableDictionary dictionaryWithDictionary:[NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/com.skitty.dune.plist"]];
				if (dunePrefs && [[NSFileManager defaultManager] fileExistsAtPath:@"/var/lib/dpkg/info/com.skitty.dune.list"])
					darkEnabled = [[dunePrefs objectForKey:@"enabled"] boolValue];

				if (currentLux >= lowluxThreshold && darkEnabled) {
					CFNotificationCenterPostNotification(CFNotificationCenterGetDistributedCenter(), CFSTR("xyz.skitty.dune.disabled"), nil, nil, true);
					CFPreferencesSetAppValue((CFStringRef)@"enabled", (CFPropertyListRef)[NSNumber numberWithBool:NO], CFSTR("com.skitty.dune"));
				} else if (currentLux < upluxThreshold && !darkEnabled) {
					CFNotificationCenterPostNotification(CFNotificationCenterGetDistributedCenter(), CFSTR("xyz.skitty.dune.enabled"), nil, nil, true);
					CFPreferencesSetAppValue((CFStringRef)@"enabled", (CFPropertyListRef)[NSNumber numberWithBool:YES], CFSTR("com.skitty.dune"));
				}
			}
		}
		if (useNightShift) {
			Status status;
			CBBlueLightClient *nightShift = [[%c(CBBlueLightClient) alloc] init];
			[nightShift getBlueLightStatus:&status];
			BOOL shiftEnabled = status.enabled;
			if (currentLux >= lowluxThreshold && shiftEnabled) {
				[nightShift setEnabled:NO];
			} else if (currentLux < upluxThreshold && !shiftEnabled) {
				[nightShift setEnabled:YES];
			}
		}
	}
}

void init_iokit() {
	ioHIDRunLoopSchedule = CFRunLoopGetMain();

	int pv1 = 0xff00;
	int pv2 = 4;
	CFNumberRef vals[2];
	CFStringRef keys[2];

	vals[0] = CFNumberCreate(CFAllocatorGetDefault(), kCFNumberSInt32Type, &pv1);
	vals[1] = CFNumberCreate(CFAllocatorGetDefault(), kCFNumberSInt32Type, &pv2);
	keys[0] = CFStringCreateWithCString(0, "PrimaryUsagePage", 0);
	keys[1] = CFStringCreateWithCString(0, "PrimaryUsage", 0);

	CFDictionaryRef matchInfo = CFDictionaryCreate(CFAllocatorGetDefault(),(const void**)keys,(const void**)vals, 2, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);

	ioHIDClient = IOHIDEventSystemClientCreate(kCFAllocatorDefault);
	IOHIDEventSystemClientSetMatching(ioHIDClient, matchInfo);

	CFArrayRef matchingsrvs = IOHIDEventSystemClientCopyServices(ioHIDClient);

	if (CFArrayGetCount(matchingsrvs) != 0) {
		IOHIDServiceClientRef alssc = (IOHIDServiceClientRef)CFArrayGetValueAtIndex(matchingsrvs, 0);

		int ri = checkInterval * 1000000; // about every 5 seconds
		CFNumberRef interval = CFNumberCreate(CFAllocatorGetDefault(), kCFNumberIntType, &ri);
		IOHIDServiceClientSetProperty(alssc, CFSTR("ReportInterval"), interval);
	}
}

void start_iokit() {
	if (ioHIDClient) {
		IOHIDEventSystemClientScheduleWithRunLoop(ioHIDClient, ioHIDRunLoopSchedule, kCFRunLoopDefaultMode);
		IOHIDEventSystemClientRegisterEventCallback(ioHIDClient, handle_event, NULL, NULL);
	}
}

void stop_iokit() {
	if (ioHIDClient) {
		IOHIDEventSystemClientUnregisterEventCallback(ioHIDClient);
		IOHIDEventSystemClientUnscheduleWithRunLoop(ioHIDClient, ioHIDRunLoopSchedule, kCFRunLoopDefaultMode);
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
