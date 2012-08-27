//
//  Zoomer.h
//  FSZoom
//
//  Created by Stephen Sykes on 23/8/12.
//  Copyright (c) 2012 Stephen Sykes. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Zoomer : NSObject {
  NSOpenGLContext *nsOpenGLContext;
  CGLContextObj   glContext;
  CGLPixelFormatObj myPixelFormat;
  CGImageRef      desktopImage;
  
  GLuint					FBOid;
	GLuint					FBOTextureId;
  
  float           ratio;
  CGRect          toRect;
  
  int             frameCounter;
  
  CVDisplayLinkRef displayLink;
}

- (void) setupWithContext:(NSOpenGLContext *)context image:(CGImageRef)image rect:(CGRect)rect ratio:(float)theRatio pixelFormat:(CGLPixelFormatObj)pixelFormat;
- (void) draw;

@end
