// LOHeader.m

#import <Preferences/PSSpecifier.h>

#define kTintColor [UIColor colorWithRed:0.0 green:0.62 blue:0.49 alpha:1.0]

@interface LOHeader : UITableViewCell

@property (nonatomic, retain) UILabel *title;
@property (nonatomic, retain)  UILabel *subtitle;

- (id)initWithSpecifier:(PSSpecifier *)specifier;

@end
