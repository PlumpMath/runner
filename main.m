//
//  main.m
//
//  Created by John Wiegley on 9/18/05.
//  Copyright 2005, New Artisans LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>

char ** scriptArgs;

int main(int argc, char *argv[])
{
  scriptArgs = &argv[1];
  return NSApplicationMain(argc,  (const char **) argv);
}
