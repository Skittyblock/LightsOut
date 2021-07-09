// iokit

#include "iokit.h"

static IOHIDEventSystemClientRef ioHIDClient;
static CFRunLoopRef ioHIDRunLoopSchedule;

void init_iokit(int checkInterval) {
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

		int ri = checkInterval * 1000000;
		CFNumberRef interval = CFNumberCreate(CFAllocatorGetDefault(), kCFNumberIntType, &ri);
		IOHIDServiceClientSetProperty(alssc, CFSTR("ReportInterval"), interval);
	}
}

void start_iokit(IOHIDEventSystemClientEventCallback callback) {
	if (ioHIDClient) {
		IOHIDEventSystemClientScheduleWithRunLoop(ioHIDClient, ioHIDRunLoopSchedule, kCFRunLoopDefaultMode);
		IOHIDEventSystemClientRegisterEventCallback(ioHIDClient, callback, NULL, NULL);
	}
}

void stop_iokit() {
	if (ioHIDClient) {
		IOHIDEventSystemClientUnregisterEventCallback(ioHIDClient);
		IOHIDEventSystemClientUnscheduleWithRunLoop(ioHIDClient, ioHIDRunLoopSchedule, kCFRunLoopDefaultMode);
	}
}
