/*===============================================================================
Copyright (c) 2016 PTC Inc. All Rights Reserved.

Copyright (c) 2012-2015 Qualcomm Connected Experiences, Inc. All Rights Reserved.

Vuforia is a trademark of PTC Inc., registered in the United States and other 
countries.
===============================================================================*/

#import <UIKit/UIKit.h>

#import <Vuforia/UIGLViewProtocol.h>

#import "Texture.h"
#import "SampleApplicationSession.h"
#import "BooksControllerDelegateProtocol.h"
#import "Transition3Dto2D.h"
#import "BooksManagerDelegateProtocol.h"
#import "ImagesManagerDelegateProtocol.h"
#import "SampleGLResourceHandler.h"
#import "SampleAppRenderer.h"

// structure to point to an object to be drawn
@interface Object3D : NSObject

@property (nonatomic) unsigned int numVertices;
@property (nonatomic) const float *vertices;
@property (nonatomic) const float *normals;
@property (nonatomic) const float *texCoords;

@property (nonatomic) unsigned int numIndices;
@property (nonatomic) const unsigned short *indices;

@property (nonatomic) Texture *texture;

@end



// Books is a subclass of UIView and conforms to the informal protocol
// UIGLViewProtocol
@interface BooksEAGLView : UIView <UIGLViewProtocol, BooksManagerDelegateProtocol, ImagesManagerDelegateProtocol, SampleGLResourceHandler, SampleAppRendererControl> {
@private
    // OpenGL ES context
    EAGLContext *context;
    
    // The OpenGL ES names for the framebuffer and renderbuffers used to render
    // to this view
    GLuint defaultFramebuffer;
    GLuint colorRenderbuffer;
    GLuint depthRenderbuffer;

    // Shader handles
    GLuint shaderProgramID;
    GLint vertexHandle;
    GLint normalHandle;
    GLint textureCoordHandle;
    GLint mvpMatrixHandle;
    GLint texSampler2DHandle;
    
    // ----------------------------------------------------------------------------
    // Trackable Data Global Variables
    // ----------------------------------------------------------------------------
    const Vuforia::TrackableResult* trackableResult;
    Vuforia::Vec2F trackableSize;
    Vuforia::Matrix34F pose;
    Vuforia::Matrix44F modelViewMatrix;
    
    SampleAppRenderer *sampleAppRenderer;
}

- (id)initWithFrame:(CGRect)frame  delegate:(id<BooksControllerDelegateProtocol>) delegate appSession:(SampleApplicationSession *) app;

- (void)setOverlayLayer:(CALayer *)overlayLayer;
- (void)enterScanningMode;

- (BOOL)isPointInsideAROverlay:(CGPoint)aPoint;

- (void)finishOpenGLESCommands;
- (void)freeOpenGLESResources;

- (bool) isTouchOnTarget:(CGPoint) touchPoint;

- (void) setOrientationTransform:(CGAffineTransform)transform withLayerPosition:(CGPoint)pos;
- (void) configureVideoBackgroundWithViewWidth:(float)viewWidth andHeight:(float)viewHeight;
- (void) updateRenderingPrimitives;

@end

