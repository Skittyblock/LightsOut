// LORootListController.m

#include "LORootListController.h"

@implementation LORootListController

- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];

  UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
  self.view.tintColor = kTintColor;
  keyWindow.tintColor = kTintColor;
  [UISwitch appearanceWhenContainedInInstancesOfClasses:@[self.class]].onTintColor = kTintColor;
}

- (void)viewWillDisappear:(BOOL)animated {
  [super viewWillDisappear:animated];

  UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
  keyWindow.tintColor = nil;
}

- (NSArray *)specifiers {
  if (!_specifiers) {
    _specifiers = [[self loadSpecifiersFromPlistName:@"Root" target:self] retain];
  }

  return _specifiers;
}

@end
