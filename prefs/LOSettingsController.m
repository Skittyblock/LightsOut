// LOSettingsController.m

#import "LOSettingsController.h"
#import "../iokit.h"

static void handleLuxChange(void *, void *, IOHIDEventQueueRef, IOHIDEventRef);

static int currentLux = 0;

@implementation LOSettingsController

- (void)viewDidLoad {
	[super viewDidLoad];

	self.levelLabel = [[UILabel alloc] init];
	self.levelLabel.font = [UIFont systemFontOfSize:12];
	self.levelLabel.textColor = [UIColor colorWithWhite:1 alpha:0.5];
	self.levelLabel.translatesAutoresizingMaskIntoConstraints = NO;
	[self.headerView addSubview:self.levelLabel];

	[NSLayoutConstraint activateConstraints:@[
		[self.levelLabel.bottomAnchor constraintEqualToAnchor:self.headerView.bottomAnchor constant:-10],
		[self.levelLabel.trailingAnchor constraintEqualToAnchor:self.headerView.trailingAnchor constant:-10]
	]];

	self.iconView.image = [UIImage imageWithContentsOfFile:[[self resourceBundle] pathForResource:@"logo" ofType:@"png"]];
	self.iconView.transform = CGAffineTransformMakeScale(0.9, 0.9);

	init_iokit(1);
	start_iokit(handleLuxChange);
	[self updateLux];
	[NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(updateLux) userInfo:nil repeats:YES];
}

- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
	stop_iokit();
}

- (void)updateLux {
	//self.headerView.subtitleLabel.text = 
	self.levelLabel.text = [NSString stringWithFormat:@"Current Level: %i", currentLux];
}

@end


// Ambient Light Sensor
static void handleLuxChange(void *target, void *refcon, IOHIDEventQueueRef queue, IOHIDEventRef event) {
	if (IOHIDEventGetType(event) == kIOHIDEventTypeAmbientLightSensor) {
		currentLux = IOHIDEventGetIntegerValue(event, (IOHIDEventField)kIOHIDEventFieldAmbientLightSensorLevel);
	}
}
