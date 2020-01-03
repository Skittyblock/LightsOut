// LightsOut, by Skitty
// Toggle dark mode/night shift with the light sensor!

#include <IOKit/hid/IOHIDEventSystem.h>
#include <IOKit/hid/IOHIDEventSystemClient.h>

extern "C" {
	int IOHIDEventSystemClientSetMatching(IOHIDEventSystemClientRef client, CFDictionaryRef match);
	CFArrayRef IOHIDEventSystemClientCopyServices(IOHIDEventSystemClientRef);
	IOHIDEventSystemClientRef IOHIDEventSystemClientCreate(CFAllocatorRef allocator);
	typedef struct __IOHIDServiceClient *IOHIDServiceClientRef;
	int IOHIDServiceClientSetProperty(IOHIDServiceClientRef, CFStringRef, CFNumberRef);
	CFNotificationCenterRef CFNotificationCenterGetDistributedCenter(void);
}

void init_iokit();
void start_iokit();
void stop_iokit();

@interface UISUserInterfaceStyleMode : NSObject
@property (nonatomic, assign) long long modeValue;
@end

typedef struct {
	int hour;
	int minute;
} Time;

typedef struct {
	Time fromTime;
	Time toTime;
} Schedule;

typedef struct {
	BOOL active;
	BOOL enabled;
	BOOL sunSchedulePermitted;
	int mode;
	Schedule schedule;
	unsigned long long disableFlags;
	BOOL available;
} Status;

@interface CBBlueLightClient : NSObject
- (BOOL)setActive:(BOOL)arg1;
- (BOOL)setEnabled:(BOOL)arg1;
- (BOOL)getBlueLightStatus:(Status *)arg1;
@end

static IOHIDEventSystemClientRef ioHIDClient;
static CFRunLoopRef ioHIDRunLoopSchedule;

static NSMutableDictionary *settings;
static BOOL enabled;
static BOOL useDarkMode;
static BOOL useNightShift;
static int luxThreshold;
static int checkInterval;

// Preference Updates
static void refreshPrefs() {
	CFArrayRef keyList = CFPreferencesCopyKeyList(CFSTR("xyz.skitty.lightsout"), kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
	if (keyList) {
		settings = (NSMutableDictionary *)CFBridgingRelease(CFPreferencesCopyMultiple(keyList, CFSTR("xyz.skitty.lightsout"), kCFPreferencesCurrentUser, kCFPreferencesAnyHost));
		CFRelease(keyList);
	} else {
		settings = nil;
	}
	if (!settings) {
		settings = [[NSMutableDictionary alloc] initWithContentsOfFile:@"/var/mobile/Library/Preferences/xyz.skitty.lightsout.plist"];
	}
	int oldEnabled = enabled;
	int oldCheckInterval = checkInterval;

	enabled = [([settings objectForKey:@"enabled"] ?: @(YES)) boolValue];
	useDarkMode = [([settings objectForKey:@"useDarkMode"] ?: @(YES)) boolValue];
	useNightShift = [([settings objectForKey:@"useNightShift"] ?: @(NO)) boolValue];
	luxThreshold = [([settings objectForKey:@"luxThreshold"] ?: @50) intValue];
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
void handle_event(void* target, void* refcon, IOHIDEventQueueRef queue, IOHIDEventRef event) {
	if (IOHIDEventGetType(event) == kIOHIDEventTypeAmbientLightSensor) {
		int currentLux = IOHIDEventGetIntegerValue(event, (IOHIDEventField)kIOHIDEventFieldAmbientLightSensorLevel);

		if (useDarkMode) {
			BOOL darkEnabled;
			if (@available(iOS 13, *)) {
				darkEnabled = ([UITraitCollection currentTraitCollection].userInterfaceStyle == UIUserInterfaceStyleDark);
				UISUserInterfaceStyleMode *styleMode = [[%c(UISUserInterfaceStyleMode) alloc] init];
				if (currentLux >= luxThreshold && darkEnabled) {
					styleMode.modeValue = 1;
				} else if (currentLux < luxThreshold && !darkEnabled)  {
					styleMode.modeValue = 2;
				}
			} else {
				// If Dune is installed, use Dune preferences. This is a little buggy.
				NSMutableDictionary *dunePrefs = [NSMutableDictionary dictionaryWithDictionary:[NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/com.skitty.dune.plist"]];
				if (dunePrefs && [[NSFileManager defaultManager] fileExistsAtPath:@"/var/lib/dpkg/info/com.skitty.dune.list"])
					darkEnabled = [[dunePrefs objectForKey:@"enabled"] boolValue];
				
				if (currentLux >= luxThreshold && darkEnabled) {
					CFNotificationCenterPostNotification(CFNotificationCenterGetDistributedCenter(), CFSTR("xyz.skitty.dune.disabled"), nil, nil, true);
					CFPreferencesSetAppValue((CFStringRef)@"enabled", (CFPropertyListRef)[NSNumber numberWithBool:NO], CFSTR("com.skitty.dune"));
				} else if (currentLux < luxThreshold && !darkEnabled)  {
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
			if (currentLux >= luxThreshold && shiftEnabled) {
				[nightShift setEnabled:NO];
			} else if (currentLux < luxThreshold && !shiftEnabled)  {
				[nightShift setEnabled:YES];
			}
		}
		//NSLog(@"[LightsOut] lux: %d, luxThreshold: %d, darkEnabled: %d, shiftEnabled: %d, useDarkMode: %d, useNightShift: %d", currentLux, luxThreshold, darkEnabled, shiftEnabled, useDarkMode, useNightShift);
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
	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback) PreferencesChangedCallback, CFSTR("xyz.skitty.lightsout.prefschanged"), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
	refreshPrefs();

	%init;
}

%dtor {
	stop_iokit();
}