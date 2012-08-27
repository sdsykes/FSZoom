//
//  AppDelegate.h
//  FSZoom
//
//  Created by Stephen Sykes on 23/8/12.
//  Copyright (c) 2012 Stephen Sykes. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Quartz/Quartz.h>

@class Zoomer;

@interface AppDelegate : NSObject <NSApplicationDelegate> {
  IBOutlet IKImageView *iView;
  CGImageRef desktopImage;
}

@property (assign) IBOutlet NSWindow *window;
@property (nonatomic, retain) NSOpenGLContext *glContext;
@property (nonatomic, retain) NSOpenGLPixelFormat *pixelFormat;
@property (nonatomic, retain) Zoomer *zoomer;
@property (nonatomic, retain) NSDate *date;

@end
