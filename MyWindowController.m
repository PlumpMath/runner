#import "MyWindowController.h"

@implementation MyWindowController

- (id)init
{
  self = [super init];
  assert(self != nil);

  task = nil;
  isSuspended = FALSE;

  [[NSNotificationCenter defaultCenter] addObserver:self 
   selector:@selector(taskCompleted:) 
   name:NSTaskDidTerminateNotification 
   object:nil];

  taskPipe = nil;

  [[NSNotificationCenter defaultCenter] addObserver:self 
   selector:@selector(outputAvailable:) 
   name:NSFileHandleReadCompletionNotification
   object:nil];

  [self readDetailsForScript:[[NSBundle mainBundle]
			      pathForResource:@"defaults" ofType:@"plist"]];

  NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];
  NSMutableDictionary * appDefaults = [[NSMutableDictionary alloc] init];
  [appDefaults
   setObject:[scriptProps objectForKey:@"DelayStart"] forKey:@"DelayStart"];
  [appDefaults
   setObject:[scriptProps objectForKey:@"AutoClose"] forKey:@"AutoClose"];
  [appDefaults
   setObject:[scriptProps objectForKey:@"NotifyClose"] forKey:@"NotifyClose"];
  [appDefaults
   setObject:[scriptProps objectForKey:@"ConfirmQuit"] forKey:@"ConfirmQuit"];
  [appDefaults setObject:@"Monaco" forKey:@"FontFace"];
  [appDefaults setObject:[NSNumber numberWithFloat:12.0] forKey:@"FontSize"];
  [defaults registerDefaults:appDefaults];

  return self;
}

- (void)readDetailsForScript:(NSString *)path
{
  NSData * plistData = [NSData dataWithContentsOfFile:path];

  NSPropertyListFormat format;
  NSString * error;

  scriptProps =
    [[NSPropertyListSerialization propertyListFromData:plistData
      mutabilityOption:NSPropertyListImmutable
      format:&format errorDescription:&error] retain];

  if (! scriptProps) {
    NSLog(error);
    [error release];
  }
}

- (void)dealloc
{
  [task release];
  [taskPipe release];
  [scriptProps release];

  [super dealloc];
}

- (void)awakeFromNib
{
  [[self window] setTitle:[scriptProps objectForKey:@"Title"]];

  NSFont * theFont;
  float defaultFontSize;

  defaultFontSize = [[NSUserDefaults standardUserDefaults]
		     floatForKey:@"FontSize"];
  theFont = [NSFont fontWithName:[[NSUserDefaults standardUserDefaults]
				  stringForKey:@"FontFace"]
	     size:defaultFontSize];

  if (! theFont)
    theFont = [NSFont userFixedPitchFontOfSize:defaultFontSize];

  [outputView setFont:theFont];

  [[self window] setFrameAutosaveName:@"MainWindow"];
  [[self window] makeKeyAndOrderFront:nil];

  if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DelayStart"]) {
    [cycleButton setTitle:@"Start"];
  } else {
    [cycleButton setTitle:@"Interrupt"];
    [self startTask];
  }
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:
        (NSApplication *)theApplication
{
  return YES;
}

#if 0
- (void)applicationDidFinishLaunching:(NSNotification*)notification
{
}
#endif

- (void)changeFont:(id)sender
{
  NSLog(@"Change font request");
  NSFont *oldFont = [outputView font]; 
  NSFont *newFont = [sender convertFont:oldFont]; 
  [outputView setFont:newFont]; 

  [[NSUserDefaults standardUserDefaults]
   setObject:[newFont fontName] forKey:@"FontFace"];
  [[NSUserDefaults standardUserDefaults]
   setObject:[NSNumber numberWithFloat:[newFont pointSize]]
   forKey:@"FontSize"];
}

- (void)startTask
{
  [outputView setString:@""];

  if (task != nil) {
    [task terminate];
    [task release];
  }
  task = [[NSTask alloc] init];

  // Next thing is to tell our app what UNIX "thing" we want to execute.
  [task setLaunchPath:[scriptProps objectForKey:@"Pathname"]];

  NSArray * args = [scriptProps objectForKey:@"Arguments"];
  if (args)
    [task setArguments:args];

  NSString * cwd = [scriptProps objectForKey:@"CurrentDir"];
  if (cwd && [cwd length] > 0)
    [task setCurrentDirectoryPath:[cwd stringByExpandingTildeInPath]];

  [taskPipe release];
  taskPipe   = [[NSPipe alloc] init];
  readHandle = [taskPipe fileHandleForReading];

  [task setStandardError:taskPipe];
  [task setStandardOutput:taskPipe];

  [readHandle readInBackgroundAndNotify];

  // And finally, we'll launch it.
  [task launch];
  [statusText setStringValue:@"Running..."];
  [statusText setTextColor:[NSColor blackColor]];

  isSuspended = FALSE;
  [pauseButton setTitle:@"Pause"];
  [pauseButton setEnabled:TRUE];

  [cycleButton setTitle:@"Interrupt"];
}

- (IBAction)pause:(id)sender
{
  if (isSuspended) {
    [task resume];
    if (sender != self)
      [sender setTitle:@"Pause"];
    isSuspended = FALSE;
    [statusText setStringValue:@"Running..."];
    [statusText setTextColor:[NSColor blackColor]];
  } else {
    [task suspend];
    if (sender != self)
      [sender setTitle:@"Resume"];
    isSuspended = TRUE;
    [statusText setStringValue:@"Paused"];
    [statusText setTextColor:[NSColor blackColor]];
  }
}

- (IBAction)cycle:(id)sender
{
  if (task == nil)
    [self startTask];
  else
    [task interrupt];
}

- (IBAction)quit:(id)sender
{
  if (task != nil) {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"ConfirmQuit"]) {
      NSAlert *alert = [[NSAlert alloc] init];
      [alert addButtonWithTitle:@"OK"];
      [alert addButtonWithTitle:@"Cancel"];
      [alert setMessageText:@"Really quit?"];
      [alert setInformativeText:@"Script will be terminated immediately."];
      [alert setAlertStyle:NSWarningAlertStyle];

      BOOL wasSuspended = isSuspended;
      if (! isSuspended)
	[self pause:self];

      if ([alert runModal] != NSAlertFirstButtonReturn) {
	// Cancel clicked
	[alert release];

	if (! wasSuspended && isSuspended)
	  [self pause:self];
	return;
      } 
      [alert release];
    }

    [task terminate];
  }

  [NSApp terminate:self];
}

- (void)outputAvailable:(NSNotification *)aNotification
{
  NSData *   taskData; 
  NSString * newOutput; 

  assert(readHandle != nil);

  taskData = [[aNotification userInfo]
	      objectForKey:@"NSFileHandleNotificationDataItem"]; 
  if ([taskData length] == 0)
    return;
  
  // Insert the output into the outputView
  newOutput = [[NSString alloc] initWithData:taskData 
	       encoding:NSMacOSRomanStringEncoding]; 

  NSRange endRange;
  endRange.location = [[outputView textStorage] length];
  endRange.length = 0;
  [outputView replaceCharactersInRange:endRange withString:newOutput];
  endRange.length = [newOutput length];
  [outputView scrollRangeToVisible:endRange];

  [newOutput release]; 

  [readHandle readInBackgroundAndNotify]; 
}

- (void)taskCompleted:(NSNotification *)aNotification
{
  assert(task == [aNotification object]);

  int status = [[aNotification object] terminationStatus];
  if (status == 0) {
    [statusText setStringValue:@"Completed."];
    [statusText setTextColor:[NSColor greenColor]];

    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"AutoClose"])
      [[self window] close];
    else if ([[NSUserDefaults standardUserDefaults] boolForKey:@"NotifyClose"])
      [NSApp requestUserAttention:NSInformationalRequest];
  } else {
    [statusText setStringValue:@"Failed!"];
    [statusText setTextColor:[NSColor redColor]];
    [NSApp requestUserAttention:NSCriticalRequest];
  }

  [task release];
  task = nil;

  [pauseButton setTitle:@"Pause"];
  [pauseButton setEnabled:FALSE];
  [cycleButton setTitle:@"Restart"];
}

@end
