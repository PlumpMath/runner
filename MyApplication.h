/* MyApplication */

#import <Cocoa/Cocoa.h>

@interface MyApplication : NSApplication
{
    IBOutlet id prefsWindow;
}

- (IBAction)openPreferencesWindow:(id)sender;
@end
