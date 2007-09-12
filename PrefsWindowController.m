#import "PrefsWindowController.h"

@implementation PrefsWindowController

- (IBAction)setAutoClose:(id)sender
{
  NSButton * button = [sender selectedCell];

  if ([button state])
    [[NSUserDefaults standardUserDefaults]
     setObject:@"YES" forKey:@"AutoClose"];
  else
    [[NSUserDefaults standardUserDefaults]
     setObject:@"NO" forKey:@"AutoClose"];
}

- (IBAction)setConfirmQuit:(id)sender
{
  NSButton * button = [sender selectedCell];

  if ([button state])
    [[NSUserDefaults standardUserDefaults]
     setObject:@"YES" forKey:@"ConfirmQuit"];
  else
    [[NSUserDefaults standardUserDefaults]
     setObject:@"NO" forKey:@"ConfirmQuit"];
}

- (IBAction)setDelayStart:(id)sender
{
  NSButton * button = [sender selectedCell];

  if ([button state])
    [[NSUserDefaults standardUserDefaults]
     setObject:@"YES" forKey:@"DelayStart"];
  else
    [[NSUserDefaults standardUserDefaults]
     setObject:@"NO" forKey:@"DelayStart"];
}

- (IBAction)setDelayOutput:(id)sender
{
  NSButton * button = [sender selectedCell];

  if ([button state])
    [[NSUserDefaults standardUserDefaults]
     setObject:@"YES" forKey:@"DelayOutput"];
  else
    [[NSUserDefaults standardUserDefaults]
     setObject:@"NO" forKey:@"DelayOutput"];
}

@end
