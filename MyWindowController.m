#import "MyWindowController.h"

#include <stdio.h>
#include <stdlib.h>
#include <sys/unistd.h>

extern char ** scriptArgs;

NSString * FindExecutableInPath(NSString * name)
{
  if ([name hasPrefix:@"/"])
    return name;

  NSString * pathEnv = [[[NSProcessInfo processInfo] environment]
			objectForKey:@"PATH"];
  NSArray * paths = [pathEnv componentsSeparatedByString:@":"];

  NSEnumerator * e = [paths objectEnumerator];
  NSString * path;
  while ((path = [e nextObject]) != nil)
    {
      NSString * executablePath = [path stringByAppendingPathComponent:name];
      if (access([executablePath cString], X_OK) != -1)
	return executablePath;
    }
  return nil;
}

@implementation MyWindowController

- (id)init
{
  self = [super init];
  if (self != nil) {
    task	= nil;
    isSuspended	= FALSE;

    [[NSNotificationCenter defaultCenter] addObserver:self 
     selector:@selector(taskCompleted:) 
     name:NSTaskDidTerminateNotification object:nil];

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
  }
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
  [scriptProps release];

  [super dealloc];
}

- (void)awakeFromNib
{
  if (scriptArgs[0]) {
    NSMutableArray * args = [[NSMutableArray alloc] init];
    int i;
    for (i = 0; scriptArgs[i]; i++) {
      [args addObject:[NSString stringWithCString:scriptArgs[i]]];
      // jww (2007-09-12): Don't break here to make the full title include all
      // program arguments
      break;
    }

    [[self window] setTitle:[args componentsJoinedByString:@" "]];
  } else {
    [[self window] setTitle:@"Welcome to Runner"];
  }

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

  NSSize size;
  size.height = [[NSUserDefaults standardUserDefaults]
		 integerForKey:@"LastKnownHeight"];
  size.width  = [[NSUserDefaults standardUserDefaults]
		 integerForKey:@"LastKnownWidth"];
  if (size.height != 0 && size.width != 0)
    [[self window] setContentSize:size];

  if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DelayStart"]) {
    [cycleButton setTitle:@"Start"];
  } else {
    [cycleButton setTitle:@"Interrupt"];
    [self startTask];
  }

  [[self window] makeKeyAndOrderFront:nil];
}

- (void)windowDidResize:(NSNotification *)aNotification
{
  NSWindow * window = [aNotification object];

  [[NSUserDefaults standardUserDefaults]
   setInteger:[window frame].size.height forKey:@"LastKnownHeight"];
  [[NSUserDefaults standardUserDefaults]
   setInteger:[window frame].size.width forKey:@"LastKnownWidth"];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:
        (NSApplication *)theApplication
{
  return YES;
}

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

- (void)outputString:(NSString *)aString
{
  NSRange endRange;
  endRange.location = [[outputView textStorage] length];
  endRange.length = 0;
  [outputView replaceCharactersInRange:endRange withString:aString];
  endRange.length = [aString length];

  [outputView scrollRangeToVisible:endRange];
}

- (void)startTask
{
  [outputView setString:@""];

  if (task != nil) {
    [task terminate];
    [task release];
  }
  task = [[NSTask alloc] init];

  int index = 0;

  while (scriptArgs[index] && scriptArgs[index][0] == '-')
    index++;
  
  if (scriptArgs[index]) {
    NSString * launchPath =
      FindExecutableInPath([NSString stringWithCString:scriptArgs[index++]]);
    if (launchPath == nil) {
      [self outputString:@"Could not find executable on the PATH"];
      return;
    } else {
      [task setLaunchPath:launchPath];
      if (scriptArgs[1]) {
	NSMutableArray * args = [[NSMutableArray alloc] init];
	for (; scriptArgs[index]; index++)
	  [args addObject:[NSString stringWithCString:scriptArgs[index]]];
	[task setArguments:args];
      }
    }
  } else {
    [task setLaunchPath:
     [[NSBundle mainBundle] pathForResource:@"defaultscript" ofType:@"sh"]];
  }

  //NSString * cwd = [scriptProps objectForKey:@"CurrentDir"];
  //if (cwd && [cwd length] > 0)
    [task setCurrentDirectoryPath:@"."];

  taskPipe   = [[NSPipe alloc] init];
  readHandle = [taskPipe fileHandleForReading];

  [task setStandardOutput:taskPipe];
  [task setStandardError:taskPipe];

  [[NSNotificationCenter defaultCenter] addObserver:self 
   selector:@selector(outputAvailable:) 
   name:NSFileHandleReadCompletionNotification
   object:readHandle];

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

    [[NSNotificationCenter defaultCenter] removeObserver:self 
     name:NSFileHandleReadCompletionNotification
     object:readHandle];

    [readHandle release];
    [taskPipe release];
  }

  [NSApp terminate:self];
}

- (void)outputAvailable:(NSNotification *)aNotification
{
  NSData *   taskData; 
  NSString * newOutput; 

  taskData = [[aNotification userInfo]
	      objectForKey:@"NSFileHandleNotificationDataItem"]; 
  if ([taskData length] == 0)
    return;
  
  // Insert the output into the outputView
  newOutput = [[NSString alloc] initWithData:taskData 
	       encoding:NSMacOSRomanStringEncoding]; 

#if 0
  if ([aNotification object] == taskErrorPipe)
    [newOutput setTextColor:[NSColor redColor]];
#endif

  [self outputString:newOutput];
  [newOutput release]; 

  [[aNotification object] readInBackgroundAndNotify]; 
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
