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
#import "SampleGLResourceHandler.h"
#import "SampleAppRenderer.h"


static const int kNumAugmentationTextures = 1;


// BackgroundTextureAccess is a subclass of UIView and conforms to the informal protocol
// UIGLViewProtocol
@interface BackgroundTextureAccessEAGLView : UIView <UIGLViewProtocol, SampleGLResourceHandler, SampleAppRendererControl> {
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
    
    // Texture used when rendering augmentation
    Texture* augmentationTexture[kNumAugmentationTextures];
    
    SampleAppRenderer *sampleAppRenderer;
    
    // Coordinates of user touch
    float touchLocation_X;
    float touchLocation_Y;
    
    // ----- Video background OpenGL data -----
    struct tagVideoBackgroundShader {
        // These handles are required to pass the values to the video background
        // shaders
        GLuint vbShaderProgramID;
        GLuint vbVertexPositionHandle;
        GLuint vbVertexTexCoordHandle;
        GLuint vbTexSampler2DHandle;
        GLuint vbProjectionMatrixHandle;
        GLuint vbTouchLocationXHandle;
        GLuint vbTouchLocationYHandle;
        
        // This flag indicates whether the mesh values have been initialized
        bool vbMeshInitialized;
    } videoBackgroundShader;
}

@property (nonatomic, weak) SampleApplicationSession * vapp;
@property (readwrite) float touchLocation_X;
@property (readwrite) float touchLocation_Y;

- (id)initWithFrame:(CGRect)frame appSession:(SampleApplicationSession *) app;

- (void)finishOpenGLESCommands;
- (void)freeOpenGLESResources;

- (void) setOrientationTransform:(CGAffineTransform)transform withLayerPosition:(CGPoint)pos;
- (void) cameraDidStart;
- (void) configureVideoBackgroundWithViewWidth:(float)viewWidth andHeight:(float)viewHeight;
- (void) updateRenderingPrimitives;
@end

