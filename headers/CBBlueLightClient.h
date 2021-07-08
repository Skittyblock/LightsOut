// CBBlueLightClient.h

#import <Foundation/Foundation.h>

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