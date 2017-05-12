/*===============================================================================
Copyright (c) 2015-2016 PTC Inc. All Rights Reserved.

 Copyright (c) 2012-2015 Qualcomm Connected Experiences, Inc. All Rights Reserved.
 
 Vuforia is a trademark of PTC Inc., registered in the United States and other
 countries.
 ===============================================================================*/

#import <QuartzCore/QuartzCore.h>
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>
#import <sys/time.h>

#import <Vuforia/Vuforia.h>
#import <Vuforia/State.h>
#import <Vuforia/Tool.h>
#import <Vuforia/Renderer.h>
#import <Vuforia/GLRenderer.h>
#import <Vuforia/MultiTargetResult.h>
#import <Vuforia/TrackableResult.h>
#import <Vuforia/VideoBackgroundConfig.h>
#import <Vuforia/VideoBackgroundTextureInfo.h>

#import "OcclusionManagementEAGLView.h"
#import "Texture.h"
#import "SampleApplicationUtils.h"
#import "SampleApplicationShaderUtils.h"
#import "Teapot.h"
#import "Cube.h"


//******************************************************************************
// *** OpenGL ES thread safety ***
//
// OpenGL ES on iOS is not thread safe.  We ensure thread safety by following
// this procedure:
// 1) Create the OpenGL ES context on the main thread.
// 2) Start the Vuforia camera, which causes Vuforia to locate our EAGLView and start
//    the render thread.
// 3) Vuforia calls our renderFrameVuforia method periodically on the render thread.
//    The first time this happens, the defaultFramebuffer does not exist, so it
//    is created with a call to createFramebuffer.  createFramebuffer is called
//    on the main thread in order to safely allocate the OpenGL ES storage,
//    which is shared with the drawable layer.  The render (background) thread
//    is blocked during the call to createFramebuffer, thus ensuring no
//    concurrent use of the OpenGL ES context.
//
//******************************************************************************


namespace {
    // --- Data private to this unit ---
    
    
    // Texture filenames
    const char* textureFilenames[] = {
        "background.png", // 0
        "teapot.png",  // 1
        "mask.png", // 2
    };
    
    float   vbOrthoProjMatrix[16];
    
    unsigned int vbShaderProgramOcclusionID     = 0;
    GLint vbVertexPositionOcclusionHandle      = 0;
    GLint vbVertexTexCoordOcclusionHandle      = 0;
    GLint vbTexSamplerVideoOcclusionHandle     = 0;
    GLint vbProjectionMatrixOcclusionHandle    = 0;
    GLint vbTexSamplerMaskOcclusionHandle      = 0;
    GLint vbViewportOriginHandle               = 0;
    GLint vbViewportSizeHandle                 = 0;
    GLint vbTextureRatioHandle                 = 0;
    
    unsigned int vbShaderProgramOcclusionReflectID  = 0;
    GLint vbVertexPositionOcclusionReflectHandle   = 0;
    GLint vbVertexTexCoordOcclusionReflectHandle   = 0;
    GLint vbTexSamplerVideoOcclusionReflectHandle  = 0;
    GLint vbProjectionMatrixOcclusionReflectHandle = 0;
    GLint vbTexSamplerMaskOcclusionReflectHandle   = 0;
    GLint vbViewportOriginReflectHandle            = 0;
    GLint vbViewportSizeReflectHandle              = 0;
    GLint vbTextureRatioReflectHandle              = 0;
    
    unsigned int vbShaderProgramID              = 0;
    GLint vbVertexPositionHandle               = 0;
    GLint vbVertexTexCoordHandle               = 0;
    GLint vbTexSamplerVideoHandle              = 0;
    GLint vbProjectionMatrixHandle             = 0;
    
    // Constants:
    const float kCubeScaleX = 0.12f * 0.75f / 2.0f;
    const float kCubeScaleY = 0.12f * 1.00f / 2.0f;
    const float kCubeScaleZ = 0.12f * 0.50f / 2.0f;
    
    static const float kTeapotScaleX            = 0.12f * 0.015f;
    static const float kTeapotScaleY            = 0.12f * 0.015f;
    static const float kTeapotScaleZ            = 0.12f * 0.015f;
}


@interface OcclusionManagementEAGLView (PrivateMethods)

- (void)initShaders;
- (void)createFramebuffer;
- (void)deleteFramebuffer;
- (void)setFramebuffer;
- (BOOL)presentFramebuffer;

@end


@implementation OcclusionManagementEAGLView

@synthesize vapp;

// You must implement this method, which ensures the view's underlying layer is
// of type CAEAGLLayer
+ (Class)layerClass
{
    return [CAEAGLLayer class];
}


//------------------------------------------------------------------------------
#pragma mark - Lifecycle

- (id)initWithFrame:(CGRect)frame appSession:(SampleApplicationSession *) app
{
    self = [super initWithFrame:frame];
    
    if (self) {
        vapp = app;
        // Enable retina mode if available on this device
        if (YES == [vapp isRetinaDisplay]) {
            [self setContentScaleFactor:[UIScreen mainScreen].nativeScale];
        }
        
        CAEAGLLayer *eaglLayer = (CAEAGLLayer *)self.layer;
        
        eaglLayer.opaque = TRUE;
        eaglLayer.drawableProperties = [NSDictionary dictionaryWithObjectsAndKeys:
                                        [NSNumber numberWithBool:FALSE], kEAGLDrawablePropertyRetainedBacking,
                                        kEAGLColorFormatRGBA8, kEAGLDrawablePropertyColorFormat,
                                        nil];
        
        sampleAppRenderer = [[SampleAppRenderer alloc] initWithSampleAppRendererControl:self deviceMode:Vuforia::Device::MODE_AR stereo:false nearPlane:0.01 farPlane:5];
        
        // Load the augmentation textures
        for (int i = 0; i < kNumAugmentationTextures; ++i) {
            augmentationTexture[i] = [[Texture alloc] initWithImageFile:[NSString stringWithCString:textureFilenames[i] encoding:NSASCIIStringEncoding]];
        }
        
        // Create the OpenGL ES context
        context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
        
        // The EAGLContext must be set for each thread that wishes to use it.
        // Set it the first time this method is called (on the main thread)
        if (context != [EAGLContext currentContext]) {
            [EAGLContext setCurrentContext:context];
        }
        
        // Generate the OpenGL ES texture and upload the texture data for use
        // when rendering the augmentation
        for (int i = 0; i < kNumAugmentationTextures; ++i) {
            GLuint textureID;
            glGenTextures(1, &textureID);
            [augmentationTexture[i] setTextureID:textureID];
            glBindTexture(GL_TEXTURE_2D, textureID);
            glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
            glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
            glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, [augmentationTexture[i] width], [augmentationTexture[i] height], 0, GL_RGBA, GL_UNSIGNED_BYTE, (GLvoid*)[augmentationTexture[i] pngData]);
        }
        
        [sampleAppRenderer initRendering];
        [self initShaders];
    }
    
    return self;
}


- (void)dealloc
{
    [self deleteFramebuffer];
    
    // Tear down context
    if ([EAGLContext currentContext] == context) {
        [EAGLContext setCurrentContext:nil];
    }
    
    for (int i = 0; i < kNumAugmentationTextures; ++i) {
        augmentationTexture[i] = nil;
    }
}

- (void) setOrientationTransform:(CGAffineTransform)transform withLayerPosition:(CGPoint)pos {
    self.layer.position = pos;
    self.transform = transform;
}


- (void)finishOpenGLESCommands
{
    // Called in response to applicationWillResignActive.  The render loop has
    // been stopped, so we now make sure all OpenGL ES commands complete before
    // we (potentially) go into the background
    if (context) {
        [EAGLContext setCurrentContext:context];
        glFinish();
    }
}


- (void)freeOpenGLESResources
{
    // Called in response to applicationDidEnterBackground.  Free easily
    // recreated OpenGL ES resources
    [self deleteFramebuffer];
    glFinish();
}


- (void)configureVideoBackgroundWithViewWidth:(float)viewWidth andHeight:(float)viewHeight
{
    [sampleAppRenderer configureVideoBackgroundWithViewWidth:viewWidth andHeight:viewHeight];
}

- (void) updateRenderingPrimitives
{
    [sampleAppRenderer updateRenderingPrimitives];
}

//------------------------------------------------------------------------------
#pragma mark - UIGLViewProtocol methods

// Draw the current frame using OpenGL
//
// This method is called by Vuforia when it wishes to render the current frame to
// the screen.
//
// *** Vuforia will call this method periodically on a background thread ***
- (void)renderFrameVuforia
{
    if (! vapp.cameraIsStarted) {
        return;
    }
    
    [sampleAppRenderer renderFrameVuforia];
}


- (void)renderFrameWithState:(const Vuforia::State &)state projectMatrix:(Vuforia::Matrix44F &)projectionMatrix andViewport:(Vuforia::Vec4I)viewport
{
    [self setFramebuffer];
    SampleApplicationUtils::checkGlError("Check gl errors prior render Frame");
    
    // Clear color and depth buffer
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    [sampleAppRenderer renderVideoBackground];
    
    SampleApplicationUtils::checkGlError("Rendering of the video background");
    //
    ////////////////////////////////////////////////////////////////////////////
    
    glEnable(GL_DEPTH_TEST);
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    
    // Did we find any trackables this frame?
    if (state.getNumTrackableResults())
    {
        // Get the trackable:
        const Vuforia::TrackableResult* result=NULL;
        int numResults=state.getNumTrackableResults();
        
        // Browse results searching for the MultiTarget
        for (int j=0;j<numResults;j++)
        {
            result = state.getTrackableResult(j);
            if (result->getType().isOfType(Vuforia::MultiTargetResult::getClassType())) break;
            result=NULL;
        }
        
        // If it was not found exit
        if (result==NULL)
        {
            // Clean up and leave
            glDisable(GL_BLEND);
            glDisable(GL_DEPTH_TEST);
            
            Vuforia::Renderer::getInstance().end();
            return;
        }
        
        
        Vuforia::Matrix44F modelViewMatrix = Vuforia::Tool::convertPose2GLMatrix(result->getPose());
        Vuforia::Matrix44F modelViewProjectionCube;
        Vuforia::Matrix44F modelViewProjectionTeapot;
        
        SampleApplicationUtils::scalePoseMatrix(kCubeScaleX, kCubeScaleY, kCubeScaleZ,
                                                &modelViewMatrix.data[0]);
        
        SampleApplicationUtils::multiplyMatrix(&projectionMatrix.data[0],
                                               &modelViewMatrix.data[0],
                                               &modelViewProjectionCube.data[0]);
        
        ////////////////////////////////////////////////////////////////////////
        // First, we render the faces that serve as a "background" to the teapot
        // This helps the user to have a visually constrained space
        // (otherwise the teapot looks floating in space)
        
        glEnable(GL_CULL_FACE);
        glCullFace(GL_FRONT);
        
        glUseProgram(shaderProgramID);
        
        glVertexAttribPointer(vertexHandle, 3, GL_FLOAT, GL_FALSE, 0,
                              (const GLvoid*) &cubeVertices[0]);
        glVertexAttribPointer(normalHandle, 3, GL_FLOAT, GL_FALSE, 0,
                              (const GLvoid*) &cubeNormals[0]);
        glVertexAttribPointer(textureCoordHandle, 2, GL_FLOAT, GL_FALSE, 0,
                              (const GLvoid*) &cubeTexCoords[0]);
        glEnableVertexAttribArray(vertexHandle);
        glEnableVertexAttribArray(normalHandle);
        glEnableVertexAttribArray(textureCoordHandle);
        
        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D, [augmentationTexture[0] textureID]);
        glUniformMatrix4fv(mvpMatrixHandle, 1, GL_FALSE,
                           (GLfloat*)&modelViewProjectionCube.data[0] );
        glDrawElements(GL_TRIANGLES, NUM_CUBE_INDEX, GL_UNSIGNED_SHORT,
                       (const GLvoid*) &cubeIndices[0]);
        
        glCullFace(GL_BACK);
        
        SampleApplicationUtils::checkGlError("Back faces of the box");
        //
        ////////////////////////////////////////////////////////////////////////
        
        
        ////////////////////////////////////////////////////////////////////////
        // Then, we render the actual teapot
        modelViewMatrix = Vuforia::Tool::convertPose2GLMatrix(result->getPose());
        SampleApplicationUtils::translatePoseMatrix(0.0f*0.012f, -0.0f*0.12f,
                                                    -0.17f*0.12f, &modelViewMatrix.data[0]);
        SampleApplicationUtils::rotatePoseMatrix(90.0f, 0.0f, 0, 1,
                                                 &modelViewMatrix.data[0]);
        SampleApplicationUtils::scalePoseMatrix(kTeapotScaleX, kTeapotScaleY, kTeapotScaleZ,
                                                &modelViewMatrix.data[0]);
        SampleApplicationUtils::multiplyMatrix(&projectionMatrix.data[0],
                                               &modelViewMatrix.data[0],
                                               &modelViewProjectionTeapot.data[0]);
        glUseProgram(shaderProgramID);
        glEnableVertexAttribArray(vertexHandle);
        glEnableVertexAttribArray(normalHandle);
        glEnableVertexAttribArray(textureCoordHandle);
        glVertexAttribPointer(vertexHandle, 3, GL_FLOAT, GL_FALSE, 0,
                              (const GLvoid*) &teapotVertices[0]);
        glVertexAttribPointer(normalHandle, 3, GL_FLOAT, GL_FALSE, 0,
                              (const GLvoid*) &teapotNormals[0]);
        glVertexAttribPointer(textureCoordHandle, 2, GL_FLOAT, GL_FALSE, 0,
                              (const GLvoid*) &teapotTexCoords[0]);
        glBindTexture(GL_TEXTURE_2D, [augmentationTexture[1] textureID]);
        glUniformMatrix4fv(mvpMatrixHandle, 1, GL_FALSE,
                           (GLfloat*)&modelViewProjectionTeapot.data[0] );
        glDrawElements(GL_TRIANGLES, NUM_TEAPOT_OBJECT_INDEX, GL_UNSIGNED_SHORT,
                       (const GLvoid*) &teapotIndices[0]);
        glBindTexture(GL_TEXTURE_2D, 0);
        ////////////////////////////////////////////////////////////////////////
        ////////////////////////////////////////////////////////////////////////
        // Finally, we render the top layer based on the video image
        // this is the layer that actually gives the "transparent look"
        // notice that we use the mask.png (textures[2]->mTextureID)
        // to define how the transparency looks
        const Vuforia::VideoBackgroundTextureInfo texInfo =
        Vuforia::Renderer::getInstance().getVideoBackgroundTextureInfo();
        float uRatio =
        ((float)texInfo.mImageSize.data[0]/(float)texInfo.mTextureSize.data[0]);
        float vRatio =
        ((float)texInfo.mImageSize.data[1]/(float)texInfo.mTextureSize.data[1]);
        
        Vuforia::Matrix44F vbProjectionMatrix = [sampleAppRenderer getVideoBackgroundProjMatrix];
        // We extract the scale factors from the projection matrix to preserve the aspect ratio and
        // we get the offset setting half on the bottom and half on the top
        float videoBackgroundXScale = vbProjectionMatrix.data[0];
        float videoBackgroundYScale = vbProjectionMatrix.data[5];
        float videoBackgroundXOffset = ((videoBackgroundXScale - 1.0) * viewport.data[2]) / 2.0;
        float videoBackgroundYOffset = ((videoBackgroundYScale - 1.0) * viewport.data[3]) / 2.0;
        
        const GLuint vbVideoTextureUnit = 0;
        const GLuint vbMaskTextureUnit = 1;
        static Vuforia::GLTextureUnit unit;
        unit.mTextureUnit = vbVideoTextureUnit;
        if (!Vuforia::Renderer::getInstance().updateVideoBackgroundTexture(&unit))
        {
            return;
        }
        
        glDepthFunc(GL_LEQUAL);
        glActiveTexture(GL_TEXTURE0);
        glActiveTexture(GL_TEXTURE0 + vbMaskTextureUnit);
        glBindTexture(GL_TEXTURE_2D, [augmentationTexture[2] textureID]);
        
        glEnable(GL_BLEND);
        glBlendFunc(GL_SRC_ALPHA,GL_ONE_MINUS_SRC_ALPHA);
        
        glUseProgram(vbShaderProgramOcclusionID);
        glVertexAttribPointer(vbVertexPositionOcclusionHandle, 3, GL_FLOAT,
                              GL_FALSE, 0, (const GLvoid*) &cubeVertices[0]);
        glVertexAttribPointer(vbVertexTexCoordOcclusionHandle, 2, GL_FLOAT,
                              GL_FALSE, 0, (const GLvoid*) &cubeTexCoords[0]);
        glEnableVertexAttribArray(vbVertexPositionOcclusionHandle);
        glEnableVertexAttribArray(vbVertexTexCoordOcclusionHandle);
        
        glUniform2f(vbViewportOriginHandle,
                    viewport.data[0] - videoBackgroundXOffset, viewport.data[1] - videoBackgroundYOffset);
        
        glUniform2f(vbViewportSizeHandle, viewport.data[2] * videoBackgroundXScale, viewport.data[3] * videoBackgroundYScale);
        glUniform2f(vbTextureRatioHandle, uRatio, vRatio);
        
        glUniform1i(vbTexSamplerVideoOcclusionHandle, vbVideoTextureUnit);
        glUniform1i(vbTexSamplerMaskOcclusionHandle, vbMaskTextureUnit);
        glUniformMatrix4fv(vbProjectionMatrixOcclusionHandle, 1, GL_FALSE,
                           (GLfloat*)&modelViewProjectionCube.data[0] );
        glDrawElements(GL_TRIANGLES, NUM_CUBE_INDEX, GL_UNSIGNED_SHORT,
                       (const GLvoid*) &cubeIndices[0]);
        glDisableVertexAttribArray(vbVertexPositionOcclusionHandle);
        glDisableVertexAttribArray(vbVertexTexCoordOcclusionHandle);
        glUseProgram(0);
        glDepthFunc(GL_LESS);
        SampleApplicationUtils::checkGlError("Transparency layer");
        //
        ////////////////////////////////////////////////////////////////////////
    }
    
    glDisable(GL_BLEND);
    glDisable(GL_DEPTH_TEST);
    
    glDisableVertexAttribArray(vertexHandle);
    glDisableVertexAttribArray(normalHandle);
    glDisableVertexAttribArray(textureCoordHandle);
    
    [self presentFramebuffer];
    
}

//------------------------------------------------------------------------------
#pragma mark - OpenGL ES management

- (void)initShaders
{
    shaderProgramID = [SampleApplicationShaderUtils createProgramWithVertexShaderFileName:@"Simple.vertsh"
                                                                   fragmentShaderFileName:@"Simple.fragsh"];
    
    if (0 < shaderProgramID) {
        vertexHandle = glGetAttribLocation(shaderProgramID, "vertexPosition");
        normalHandle = glGetAttribLocation(shaderProgramID, "vertexNormal");
        textureCoordHandle = glGetAttribLocation(shaderProgramID, "vertexTexCoord");
        mvpMatrixHandle = glGetUniformLocation(shaderProgramID, "modelViewProjectionMatrix");
        texSampler2DHandle  = glGetUniformLocation(shaderProgramID,"texSampler2D");
    }
    else {
        NSLog(@"Could not initialise augmentation shader");
    }
    
    vbShaderProgramID                   = [SampleApplicationShaderUtils createProgramWithVertexShaderFileName:@"PassThrough.vertsh"
                                                                                       fragmentShaderFileName:@"PassThrough.fragsh"];
    vbVertexPositionHandle              =
    glGetAttribLocation(vbShaderProgramID, "vertexPosition");
    vbVertexTexCoordHandle              =
    glGetAttribLocation(vbShaderProgramID, "vertexTexCoord");
    vbProjectionMatrixHandle            =
    glGetUniformLocation(vbShaderProgramID, "modelViewProjectionMatrix");
    vbTexSamplerVideoHandle             =
    glGetUniformLocation(vbShaderProgramID, "texSamplerVideo");
    SampleApplicationUtils::setOrthoMatrix(-1.0, 1.0, -1.0, 1.0, -1.0, 1.0,
                                           vbOrthoProjMatrix);
    
    vbShaderProgramOcclusionID          = [SampleApplicationShaderUtils createProgramWithVertexShaderFileName:@"PassThrough.vertsh"
                                                                                       fragmentShaderFileName:@"Occlusion.fragsh"];
    vbVertexPositionOcclusionHandle     =
    glGetAttribLocation(vbShaderProgramOcclusionID, "vertexPosition");
    vbVertexTexCoordOcclusionHandle     =
    glGetAttribLocation(vbShaderProgramOcclusionID, "vertexTexCoord");
    vbProjectionMatrixOcclusionHandle   =
    glGetUniformLocation(vbShaderProgramOcclusionID,
                         "modelViewProjectionMatrix");
    vbViewportOriginHandle              =
    glGetUniformLocation(vbShaderProgramOcclusionID, "viewportOrigin");
    vbViewportSizeHandle                =
    glGetUniformLocation(vbShaderProgramOcclusionID, "viewportSize");
    vbTextureRatioHandle                =
    glGetUniformLocation(vbShaderProgramOcclusionID, "textureRatio");
    vbTexSamplerVideoOcclusionHandle       =
    glGetUniformLocation(vbShaderProgramOcclusionID, "texSamplerVideo");
    vbTexSamplerMaskOcclusionHandle     =
    glGetUniformLocation(vbShaderProgramOcclusionID, "texSamplerMask");
    
    
    vbShaderProgramOcclusionReflectID       =  [SampleApplicationShaderUtils createProgramWithVertexShaderFileName:@"PassThrough.vertsh"
                                                                                              withVertexShaderDefs:nil                    // No preprocessor defs for vertex shader
                                                                                            fragmentShaderFileName:@"Occlusion.fragsh"
                                                                                            withFragmentShaderDefs:@"#define REFLECT\n"]; // Define reflection for the fragment shader
    
    vbVertexPositionOcclusionReflectHandle  =
    glGetAttribLocation(vbShaderProgramOcclusionReflectID, "vertexPosition");
    vbVertexTexCoordOcclusionReflectHandle  =
    glGetAttribLocation(vbShaderProgramOcclusionReflectID, "vertexTexCoord");
    vbTexSamplerVideoOcclusionReflectHandle =
    glGetUniformLocation(vbShaderProgramOcclusionReflectID, "texSamplerVideo");
    vbProjectionMatrixOcclusionReflectHandle=
    glGetUniformLocation(vbShaderProgramOcclusionReflectID,
                         "modelViewProjectionMatrix");
    vbTexSamplerMaskOcclusionReflectHandle  =
    glGetUniformLocation(vbShaderProgramOcclusionReflectID, "texSamplerMask");
    vbViewportOriginReflectHandle           =
    glGetUniformLocation(vbShaderProgramOcclusionReflectID, "viewportOrigin");
    vbViewportSizeReflectHandle             =
    glGetUniformLocation(vbShaderProgramOcclusionReflectID, "viewportSize");
    vbTextureRatioReflectHandle             =
    glGetUniformLocation(vbShaderProgramOcclusionReflectID, "textureRatio");
}


- (void)createFramebuffer
{
    if (context) {
        // Create default framebuffer object
        glGenFramebuffers(1, &defaultFramebuffer);
        glBindFramebuffer(GL_FRAMEBUFFER, defaultFramebuffer);
        
        // Create colour renderbuffer and allocate backing store
        glGenRenderbuffers(1, &colorRenderbuffer);
        glBindRenderbuffer(GL_RENDERBUFFER, colorRenderbuffer);
        
        // Allocate the renderbuffer's storage (shared with the drawable object)
        [context renderbufferStorage:GL_RENDERBUFFER fromDrawable:(CAEAGLLayer*)self.layer];
        GLint framebufferWidth;
        GLint framebufferHeight;
        glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &framebufferWidth);
        glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &framebufferHeight);
        
        // Create the depth render buffer and allocate storage
        glGenRenderbuffers(1, &depthRenderbuffer);
        glBindRenderbuffer(GL_RENDERBUFFER, depthRenderbuffer);
        glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT16, framebufferWidth, framebufferHeight);
        
        // Attach colour and depth render buffers to the frame buffer
        glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, colorRenderbuffer);
        glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, depthRenderbuffer);
        
        // Leave the colour render buffer bound so future rendering operations will act on it
        glBindRenderbuffer(GL_RENDERBUFFER, colorRenderbuffer);
    }
}


- (void)deleteFramebuffer
{
    if (context) {
        [EAGLContext setCurrentContext:context];
        
        if (defaultFramebuffer) {
            glDeleteFramebuffers(1, &defaultFramebuffer);
            defaultFramebuffer = 0;
        }
        
        if (colorRenderbuffer) {
            glDeleteRenderbuffers(1, &colorRenderbuffer);
            colorRenderbuffer = 0;
        }
        
        if (depthRenderbuffer) {
            glDeleteRenderbuffers(1, &depthRenderbuffer);
            depthRenderbuffer = 0;
        }
    }
}


- (void)setFramebuffer
{
    // The EAGLContext must be set for each thread that wishes to use it.  Set
    // it the first time this method is called (on the render thread)
    if (context != [EAGLContext currentContext]) {
        [EAGLContext setCurrentContext:context];
    }
    
    if (!defaultFramebuffer) {
        // Perform on the main thread to ensure safe memory allocation for the
        // shared buffer.  Block until the operation is complete to prevent
        // simultaneous access to the OpenGL context
        [self performSelectorOnMainThread:@selector(createFramebuffer) withObject:self waitUntilDone:YES];
    }
    
    glBindFramebuffer(GL_FRAMEBUFFER, defaultFramebuffer);
}


- (BOOL)presentFramebuffer
{
    // setFramebuffer must have been called before presentFramebuffer, therefore
    // we know the context is valid and has been set for this (render) thread
    
    // Bind the colour render buffer and present it
    glBindRenderbuffer(GL_RENDERBUFFER, colorRenderbuffer);
    
    return [context presentRenderbuffer:GL_RENDERBUFFER];
}



@end

