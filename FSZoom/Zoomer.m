//
//  Zoomer.m
//  FSZoom
//
//  Created by Stephen Sykes on 23/8/12.
//  Copyright (c) 2012 Stephen Sykes. All rights reserved.
//

#import "Zoomer.h"
#import <QuartzCore/QuartzCore.h>
#import <OpenGL/glu.h>

#import "AppDelegate.h"

#define DESKTOP_SCALE 0.55
#define FRAME_COUNT 125

static Zoomer *zoomer;

@implementation Zoomer

#pragma mark - Display link

// see http://developer.apple.com/library/mac/#qa/qa1385/_index.html

// This is the renderer output callback function
static CVReturn MyDisplayLinkCallback(CVDisplayLinkRef displayLink, const CVTimeStamp* now, const CVTimeStamp* outputTime, CVOptionFlags flagsIn, CVOptionFlags* flagsOut, void* displayLinkContext)
{
  [zoomer draw];
  return kCVReturnSuccess;
}

- (void) setupCVDisplayLink
{
  // Synchronize buffer swaps with vertical refresh rate
  GLint swapInt = 1;
  CGLSetParameter(glContext, kCGLCPSwapInterval, &swapInt);
  
  // Create a display link capable of being used with all active displays
  CVDisplayLinkCreateWithActiveCGDisplays(&displayLink);
  
  // Set the renderer output callback function
  CVDisplayLinkSetOutputCallback(displayLink, &MyDisplayLinkCallback, self);
  
  // Set the display link for the current renderer
  CVDisplayLinkSetCurrentCGDisplayFromOpenGLContext(displayLink, glContext, myPixelFormat);
}

#pragma mark - FBO

// Create or update the hardware accelerated offscreen area
// Framebuffer object aka. FBO
- (void)setFBO:(CGRect)imageRect
{
  float imageAspectRatio = imageRect.size.width / imageRect.size.height;
  
	// If not previously setup
	// generate IDs for FBO and its associated texture
	if (!FBOid)
	{
		// Make sure the framebuffer extenstion is supported
		const GLubyte* strExt;
		GLboolean isFBO;
		// Get the extenstion name string.
		// It is a space-delimited list of the OpenGL extenstions
		// that are supported by the current renderer
		strExt = glGetString(GL_EXTENSIONS);
		isFBO = gluCheckExtension((const GLubyte*)"GL_EXT_framebuffer_object", strExt);
		if (!isFBO)
		{
			NSLog(@"Your system does not support framebuffer extension");
		}
		
		// create FBO object
		glGenFramebuffersEXT(1, &FBOid);
		// the texture
		glGenTextures(1, &FBOTextureId);
	}
	
	// Bind to FBO
	glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, FBOid);
	
	// Sanity check against maximum OpenGL texture size
	// If bigger adjust to maximum possible size
	// while maintain the aspect ratio
	GLint maxTexSize;
	glGetIntegerv(GL_MAX_TEXTURE_SIZE, &maxTexSize);
  NSLog(@"imageRect: %@ max: %d", NSStringFromRect(imageRect), maxTexSize);
	if (imageRect.size.width > maxTexSize || imageRect.size.height > maxTexSize)
	{
		if (imageAspectRatio > 1)
		{
			imageRect.size.width = maxTexSize;
			imageRect.size.height = maxTexSize / imageAspectRatio;
		}
		else
		{
			imageRect.size.width = maxTexSize * imageAspectRatio ;
			imageRect.size.height = maxTexSize;
		}
	}
	
	// Initialize FBO Texture
	glBindTexture(GL_TEXTURE_RECTANGLE_ARB, FBOTextureId);
	// Using GL_LINEAR because we want a linear sampling for this particular case
	// if your intention is to simply get the bitmap data out of Core Image
	// you might want to use a 1:1 rendering and GL_NEAREST
	glTexParameteri(GL_TEXTURE_RECTANGLE_ARB, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
	glTexParameteri(GL_TEXTURE_RECTANGLE_ARB, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
	glTexParameteri(GL_TEXTURE_RECTANGLE_ARB, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
	glTexParameteri(GL_TEXTURE_RECTANGLE_ARB, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
	
	// the GPUs like the GL_BGRA / GL_UNSIGNED_INT_8_8_8_8_REV combination
	// others are also valid, but might incur a costly software translation.
	glTexImage2D(GL_TEXTURE_RECTANGLE_ARB, 0, GL_RGBA, imageRect.size.width, imageRect.size.height, 0, GL_BGRA, GL_UNSIGNED_INT_8_8_8_8_REV, NULL);
	
	// and attach texture to the FBO as its color destination
	glFramebufferTexture2DEXT(GL_FRAMEBUFFER_EXT, GL_COLOR_ATTACHMENT0_EXT, GL_TEXTURE_RECTANGLE_ARB, FBOTextureId, 0);
	
	// Make sure the FBO was created succesfully.
	if (GL_FRAMEBUFFER_COMPLETE_EXT != glCheckFramebufferStatusEXT(GL_FRAMEBUFFER_EXT))
	{
		NSLog(@"Framebuffer Object creation or update failed!");
	}
  
	// unbind FBO
	glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, 0);
}

#pragma mark - texture

// this is interesting: https://github.com/beelsebob/Cocoa-GL-Tutorial-2

typedef struct {
  void *data;
  GLfloat width;
  GLfloat height;
} TextureData;

- (TextureData) textureFromImage:(CGImageRef)image width:(int)width height:(int)height
{
  void *data = malloc(width * height * 4);
  
  CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
  NSAssert(colorSpace, @"Colorspace not created.");
  
  CGContextRef context = CGBitmapContextCreate(data,
                                               width,
                                               height,
                                               8,
                                               width * 4,
                                               colorSpace,
                                               kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Host);
  NSAssert(context, @"Context not created.");
  
  CGColorSpaceRelease(colorSpace);
  // Flip so that it isn't upside-down
  CGContextTranslateCTM(context, 0, height);
  CGContextScaleCTM(context, 1.0f, -1.0f);
  CGContextSetBlendMode(context, kCGBlendModeCopy);
  CGContextDrawImage(context, CGRectMake(0, 0, width, height), image);
  CGContextRelease(context);
  
  return (TextureData){ data, width, height };
}

- (void) drawFBO
{
  CGRect sizeRect = CGRectMake(0, 0, CGImageGetWidth(desktopImage), CGImageGetHeight(desktopImage));
  CGRect scaledRect = CGRectMake(0, 0, sizeRect.size.width * DESKTOP_SCALE, sizeRect.size.height * DESKTOP_SCALE);
	GLint width = (GLint)ceil(scaledRect.size.width);
	GLint height = (GLint)ceil(scaledRect.size.height);
  
  
  CGLSetCurrentContext(glContext);
	// Enable texturing
	glEnable(GL_TEXTURE_RECTANGLE_ARB);
  
  [self setFBO:scaledRect];
  
  // draw into the FBO
  
  // bind FBO
  glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, FBOid);
  
  TextureData td = [self textureFromImage:desktopImage width:width height:height];
  
  glTexImage2D(GL_TEXTURE_RECTANGLE_ARB, 0, GL_RGBA, td.width, td.height, 0, GL_BGRA, GL_UNSIGNED_INT_8_8_8_8_REV, td.data);
  // Bind to default framebuffer (unbind FBO)
	glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, 0);
}

#pragma mark - lifecycle

- (void) setupWithContext:(NSOpenGLContext *)context image:(CGImageRef)image rect:(CGRect)rect ratio:(float)theRatio pixelFormat:(CGLPixelFormatObj)pixelFormat
{
  nsOpenGLContext = context;
  glContext = [context CGLContextObj];
  desktopImage = image;
  toRect = rect;
  ratio = theRatio;
  myPixelFormat = pixelFormat;
  zoomer = self;
  frameCounter = 0;
  [self drawFBO];
  [self setupCVDisplayLink];
  CVDisplayLinkStart(displayLink);
}

- (void) finished
{
  CVDisplayLinkStop(displayLink);
  [nsOpenGLContext clearDrawable];
  CGLClearDrawable(glContext);  // I guess it does the same
//  CGReleaseAllDisplays();
//  CGDisplayShowCursor(kCGDirectMainDisplay);
  return;
}

- (void) dealloc
{
  glDeleteFramebuffersEXT(1, &FBOid);
  glDeleteTextures(1, &FBOTextureId);

  [super dealloc];
}

#pragma mark - draw something

- (void) draw
{
  double timePassed_ms = [[(AppDelegate *)[[NSApplication sharedApplication] delegate] date] timeIntervalSinceNow] * -1000.0;
  NSLog(@"draw %f mainThread? %d", timePassed_ms, [NSThread isMainThread]);
  
  if (frameCounter > FRAME_COUNT) {
    [self finished];
    return;
  }
  
  CGRect sizeRect = CGRectMake(0, 0, CGImageGetWidth(desktopImage), CGImageGetHeight(desktopImage));
  CGRect scaledRect = CGRectMake(0, 0, sizeRect.size.width * DESKTOP_SCALE, sizeRect.size.height * DESKTOP_SCALE);
  float imageAspectRatio = sizeRect.size.width / sizeRect.size.height;
  
  // Setup OpenGL with a perspective projection
	// and back to 3D stuff with the depth buffer
  float fractionDone = (float)frameCounter / FRAME_COUNT;
  frameCounter++;

	{
    CGLSetCurrentContext(glContext);
    
		glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
		
		glViewport(0, 0, sizeRect.size.width, sizeRect.size.height);
		
		glMatrixMode(GL_PROJECTION);
		glLoadIdentity();
		gluPerspective(60.0, sizeRect.size.width / sizeRect.size.height, .1, 100.0);
    
		glMatrixMode(GL_TEXTURE);
		glLoadIdentity();
		// the GL_TEXTURE_RECTANGLE_ARB doesn't use normalized coordinates
		// scale the texture matrix to "increase" the texture coordinates
		// back to the image size
		glScalef(scaledRect.size.width,scaledRect.size.height,1.0f);
		
    
		glMatrixMode(GL_MODELVIEW);
		glLoadIdentity();
    float trz = (1.0 - cos(fractionDone * M_PI_2)) * (-1.0 / ratio + 1.32) - 0.87;
    //    lg(@"trz %f ratio %f done %f", trz, ratio, fractionDone);
		glTranslatef(0.0, -0.5f, trz);
	}
	
  // Draw the image right side up
	// again using the texture from the FBO
  glBindTexture(GL_TEXTURE_RECTANGLE_ARB,FBOTextureId);
	// Using GL_REPLACE because we want the image colors
	// unaffected by the quad color.
  glTexEnvf(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_REPLACE);
	// Draw a quad with the correct aspect ratio of the image
	glPushMatrix();
	{
		glScalef(imageAspectRatio,1.0f,1.0f);
		glBegin(GL_QUADS);
		{
			glTexCoord2f( 1.0f, 1.0f ); glVertex2f(  0.5f, 1.0f );
			glTexCoord2f( 0.0f, 1.0f ); glVertex2f( -0.5f, 1.0f );
			glTexCoord2f( 0.0f, 0.0f ); glVertex2f( -0.5f, 0.0f );
			glTexCoord2f( 1.0f, 0.0f ); glVertex2f(  0.5f, 0.0f );
		}
		glEnd();
	}
	glPopMatrix();
  
  glFlush();
}

@end

