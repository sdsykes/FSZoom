//
//  AppDelegate.m
//  FSZoom
//
//  Created by Stephen Sykes on 23/8/12.
//  Copyright (c) 2012 Stephen Sykes. All rights reserved.
//

// Important: I cannot use a NSView or NSWindow or friends.

// I do have a CALayer tree that I can add a layer to, my first approach was to use
// a CAOpenGLLayer but performance was bad
// here could be a hint as to why
// http://lists.apple.com/archives/quicktime-api/2008/Sep/msg00026.html

// So I tried to draw on the screen more directly using a context set up for that purpose

// This code works *sometimes* when I run it. I have no idea why it doesn't work most of the time.
// Obviously I am not an opengl programmer :)

// If this code crashes while running connected to the debugger it is likely to lock your screen and render
// your machine unusable until you power down. You have been warned.

#import "AppDelegate.h"
#import "Zoomer.h"

@implementation AppDelegate

@synthesize date, zoomer, glContext, pixelFormat;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
  // Insert code here to initialize your application
  desktopImage = [self currentDesktopCG];
  [iView setImage:desktopImage imageProperties:nil];
}

- (IBAction) doZoom:(id)sender
{
//  desktopImage = [self currentDesktopCG];
  [self zoomFromDesktop:CGRectMake(0, 0, 496, 310) ratio:0.295];
}

NSOpenGLPixelFormat *createPixelFormat() {
  NSOpenGLPixelFormatAttribute   attribsAntialised[] =
	{
		NSOpenGLPFAAccelerated,
		NSOpenGLPFANoRecovery,
		NSOpenGLPFADoubleBuffer,
		NSOpenGLPFAColorSize, 24,
		NSOpenGLPFAAlphaSize,  8,
		NSOpenGLPFAMultisample,
		NSOpenGLPFASampleBuffers, 1,
		NSOpenGLPFASamples, 4,
    NSOpenGLPFAFullScreen,
		0
	};
	
	// A little less requirements if the above fails.
	NSOpenGLPixelFormatAttribute   attribsBasic[] =
	{
    //		NSOpenGLPFAAccelerated,
    //		NSOpenGLPFADoubleBuffer,
    //		NSOpenGLPFAColorSize, 24,
    //		NSOpenGLPFAAlphaSize,  8,
    NSOpenGLPFAFullScreen,
    NSOpenGLPFAScreenMask, CGDisplayIDToOpenGLDisplayMask(CGMainDisplayID()),
    NSOpenGLPFANoRecovery,
		0
	};
	
	NSOpenGLPixelFormat *pixelFormat = [[[NSOpenGLPixelFormat alloc] initWithAttributes:attribsAntialised] autorelease];
	
	if (nil == pixelFormat) {
		NSLog(@"Couldn't find an FSAA pixel format, trying something more basic");
		pixelFormat = [[[NSOpenGLPixelFormat alloc] initWithAttributes:attribsBasic] autorelease];
    if (pixelFormat == nil) NSLog(@"No pixel format");
	}
  return pixelFormat;
}

NSOpenGLContext* createScreenContext(NSOpenGLPixelFormat *pixelFormat) {
  // CGDisplayErr err;
  //  err = CGCaptureAllDisplays();
  //  if (err != CGDisplayNoErr) return nil;

  // Create the context object.
  NSOpenGLContext* glContext =[[[NSOpenGLContext alloc] initWithFormat:pixelFormat shareContext:nil] autorelease];
//  if (!glContext){
//    CGReleaseAllDisplays();
//    return nil;
//  }
  // Go to full screen mode.
  // This doesn't work. See https://developer.apple.com/library/mac/#releasenotes/Cocoa/AppKit.html about NSOpenGL
  // [glContext setFullScreen];
  // [glContext update];
  
  // This seems to work but is deprecated. No sign of a replacement.
  // http://stackoverflow.com/questions/3637566/draw-into-fullscreen-gl-context
  CGLSetFullScreenOnDisplay([glContext CGLContextObj], CGDisplayIDToOpenGLDisplayMask(CGMainDisplayID()));
  
  // Make this context current so that it receives OpenGL calls.
  [glContext makeCurrentContext];
  return glContext;
}

- (CGImageRef) currentDesktopCG
{
  CGImageRef imageRef = CGWindowListCreateImage(CGRectInfinite, kCGWindowListOptionAll, kCGNullWindowID, kCGWindowImageDefault);
  return imageRef;
}

- (void) zoomFromDesktop:(CGRect)rect ratio:(float)ratio
{
  self.date = [NSDate date];
  if (!pixelFormat) {
    self.pixelFormat = createPixelFormat();
  }
  self.glContext = createScreenContext(pixelFormat);
  if (!zoomer) self.zoomer = [[Zoomer alloc] init];
  [zoomer setupWithContext:glContext image:desktopImage rect:rect ratio:ratio pixelFormat:[pixelFormat CGLPixelFormatObj]];
}

- (void) dealloc
{
  [zoomer release];
  [super dealloc];
}

@end
