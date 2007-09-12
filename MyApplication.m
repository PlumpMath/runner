#import "MyApplication.h"

@implementation MyApplication

- (void)openPreferencesWindow:(id)sender
{
  if (prefsWindow == nil)
    [NSBundle loadNibNamed:@"Preferences" owner:self];

  [prefsWindow makeKeyAndOrderFront:self];
}

@end
