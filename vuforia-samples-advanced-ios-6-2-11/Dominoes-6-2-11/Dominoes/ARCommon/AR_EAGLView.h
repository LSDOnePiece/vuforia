/*===============================================================================
Copyright (c) 2016 PTC Inc. All Rights Reserved.

Copyright (c) 2012-2014 Qualcomm Connected Experiences, Inc. All Rights Reserved.

Vuforia is a trademark of PTC Inc., registered in the United States and other 
countries.
===============================================================================*/

#import <UIKit/UIKit.h>
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES1/gl.h>
#import <OpenGLES/ES1/glext.h>
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>
#import <Vuforia/UIGLViewProtocol.h>

@class Texture;

// structure to point to an object to be drawn
@interface Object3D : NSObject

@property (nonatomic) unsigned int numVertices;
@property (nonatomic) const float *vertices;
@property (nonatomic) const float *normals;
@property (nonatomic) const float *texCoords;

@property (nonatomic) unsigned int numIndices;
@property (nonatomic) const unsigned short *indices;

@property (nonatomic, strong) Texture *texture;

@end


@class Vuforiautils;

// This class wraps the CAEAGLLayer from CoreAnimation into a convenient UIView
// subclass.  The view content is basically an EAGL surface you render your
// OpenGL scene into.  Note that setting the view non-opaque will only work if
// the EAGL surface has an alpha channel.
@interface AR_EAGLView : UIView <UIGLViewProtocol>

{
@public
    NSMutableArray *textureList; // list of textures to load
    
@protected
    Vuforiautils *vUtils; // Vuforia utils class
    
    EAGLContext *context;
    
    // The pixel dimensions of the CAEAGLLayer.
    GLint framebufferWidth;
    GLint framebufferHeight;
    
    // The OpenGL ES names for the framebuffer and renderbuffers used to render
    // to this view.
    GLuint defaultFramebuffer;
    GLuint colorRenderbuffer;
    GLuint depthRenderbuffer;
    
    NSMutableArray* textures;   // loaded textures
    NSMutableArray *objects3D;  // objects to draw
    BOOL renderingInited;
    
#ifndef USE_OPENGL1
    // *** Note, OpenGL ES 1.x is supported only in the ImageTargets sample ***
    // OpenGL 2 data
    GLuint shaderProgramID;
    GLint vertexHandle;
    GLint normalHandle;
    GLint textureCoordHandle;
    GLint mvpMatrixHandle;
    GLint texSampler2DHandle;
#endif
}

@property (nonatomic, strong) NSMutableArray *textureList;

- (void) useTextures:(NSMutableArray *)theTextures;

// OpenGL ES clean up when going into the background
- (void)finishOpenGLESCommands;
- (void)freeOpenGLESResources;

// for overriding in the EAGLView subclass
- (void)setFramebuffer;
- (BOOL)presentFramebuffer;
- (void)createFramebuffer;
- (void)deleteFramebuffer;
- (void)initRendering;
- (void)initShaders;

@end
