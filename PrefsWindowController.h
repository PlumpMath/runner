/* PrefsWindowController */

#import <Cocoa/Cocoa.h>

@interface PrefsWindowController : NSWindowController
{
}

- (IBAction)setAutoClose:(id)sender;
- (IBAction)setConfirmQuit:(id)sender;
- (IBAction)setDelayStart:(id)sender;
- (IBAction)setDelayOutput:(id)sender;
@end
