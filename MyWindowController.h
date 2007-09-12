/* MyWindowController */

#import <Cocoa/Cocoa.h>
#import <Foundation/NSTask.h>
#import <Foundation/NSFileHandle.h>

@interface MyWindowController : NSWindowController
{
  IBOutlet NSTextView *	 outputView;
  IBOutlet NSButton *	 pauseButton;
  IBOutlet NSButton *	 cycleButton;
  IBOutlet NSTextField * statusText;

  NSTask *       task;
  BOOL           isSuspended;
  NSPipe *	 taskPipe;
  NSFileHandle * readHandle;
  NSDictionary * scriptProps;
}

- (IBAction)pause:(id)sender;
- (IBAction)cycle:(id)sender;
- (IBAction)quit:(id)sender;

- (void)readDetailsForScript:(NSString *)path;
- (void)startTask;
@end
