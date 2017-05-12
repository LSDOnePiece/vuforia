/*===============================================================================
Copyright (c) 2016 PTC Inc. All Rights Reserved.

Copyright (c) 2012-2014 Qualcomm Connected Experiences, Inc. All Rights Reserved.

Vuforia is a trademark of PTC Inc., registered in the United States and other 
countries.
===============================================================================*/

// Subclassed from AR_EAGLView
#import "EAGLView.h"
#import "Dominoes.h"
#import "Texture.h"
#import <Vuforia/GLRenderer.h>
#import <Vuforia/Renderer.h>
#import <Vuforia/StateUpdater.h>
#import <Vuforia/TrackerManager.h>
#import <Vuforia/VirtualButton.h>
#import <Vuforia/UpdateCallback.h>
#import <Vuforia/Device.h>

#import "Vuforiautils.h"
#import "ShaderUtils.h"
#import "SampleApplicationShaderUtils.h"


namespace {
    
    // Texture filenames
    const char* textureFilenames[] = {
        "texture_domino.png",
        "green_glow.png",
        "blue_glow.png"
    };
    
    class VirtualButton_UpdateCallback : public Vuforia::UpdateCallback {
        virtual void Vuforia_onUpdate(Vuforia::State& state);
    } vuforiaUpdate;
    
}

@interface EAGLView()

// Video background shader
@property (nonatomic, readwrite) GLuint vbShaderProgramID;
@property (nonatomic, readwrite) GLint vbVertexHandle;
@property (nonatomic, readwrite) GLint vbTexCoordHandle;
@property (nonatomic, readwrite) GLint vbTexSampler2DHandle;
@property (nonatomic, readwrite) GLint vbProjectionMatrixHandle;
// The current set of rendering primitives
@property (nonatomic, readwrite) Vuforia::RenderingPrimitives *currentRenderingPrimitives;

@end


@implementation EAGLView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    
	if (self)
    {
        // create list of textures we want loading - ARViewController will do this for us
        int nTextures = sizeof(textureFilenames) / sizeof(textureFilenames[0]);
        for (int i = 0; i < nTextures; ++i)
            [textureList addObject: [NSString stringWithUTF8String:textureFilenames[i]]];
    }
    
    return self;
}


// Pass touch events through to the Dominoes module
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    UITouch* touch = [touches anyObject];
    CGPoint location = [touch locationInView:self];
    dominoesTouchEvent(ACTION_DOWN, 0, location.x, location.y);
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    UITouch* touch = [touches anyObject];
    CGPoint location = [touch locationInView:self];
    dominoesTouchEvent(ACTION_CANCEL, 0, location.x, location.y);
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    UITouch* touch = [touches anyObject];
    CGPoint location = [touch locationInView:self];
    dominoesTouchEvent(ACTION_UP, 0, location.x, location.y);
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    UITouch* touch = [touches anyObject];
    CGPoint location = [touch locationInView:self];
    dominoesTouchEvent(ACTION_MOVE, 0, location.x, location.y);
}

////////////////////////////////////////////////////////////////////////////////
// Initialise the application
- (void)initApplication
{
    initializeDominoes();
}


- (void) setup3dObjects
{
    dominoesSetTextures(textures);
}

- (void)initShaders
{
    [super initShaders];
    
    dominoesSetShaderProgramID(shaderProgramID);
    dominoesSetVertexHandle(vertexHandle);
    dominoesSetNormalHandle(normalHandle);
    dominoesSetTextureCoordHandle(textureCoordHandle);
    dominoesSetMvpMatrixHandle(mvpMatrixHandle);
    dominoesSetTexSampler2DHandle(texSampler2DHandle);
    
    // Video background rendering
    self.vbShaderProgramID = [SampleApplicationShaderUtils createProgramWithVertexShaderFileName:@"Background.vertsh"
                                                                          fragmentShaderFileName:@"Background.fragsh"];
    
    if (0 < self.vbShaderProgramID) {
        self.vbVertexHandle = glGetAttribLocation(self.vbShaderProgramID, "vertexPosition");
        self.vbTexCoordHandle = glGetAttribLocation(self.vbShaderProgramID, "vertexTexCoord");
        self.vbProjectionMatrixHandle = glGetUniformLocation(self.vbShaderProgramID, "projectionMatrix");
        self.vbTexSampler2DHandle = glGetUniformLocation(self.vbShaderProgramID, "texSampler2D");
    }
    else {
        NSLog(@"Could not initialise video background shader");
    }
    
}

- (void)updateRenderingPrimitives
{
    delete self.currentRenderingPrimitives;
    self.currentRenderingPrimitives = new Vuforia::RenderingPrimitives(Vuforia::Device::getInstance().getRenderingPrimitives());
}

////////////////////////////////////////////////////////////////////////////////
// Do the things that need doing after initialisation
// called after Vuforia is initialised but before the camera starts
- (void)postInitVuforia
{
    // Here we could make a Vuforia::setHint call to set the maximum
    // number of simultaneous targets                
    // Vuforia::setHint(Vuforia::HINT_MAX_SIMULTANEOUS_IMAGE_TARGETS, 2);
    
    // register for our call back after tracker processing is done
    Vuforia::registerCallback(&vuforiaUpdate);
}


// Multiply the two matrices A and B and write the result to C
void
multiplyMatrix(float *matrixA, float *matrixB, float *matrixC)
{
    int i, j, k;
    float aTmp[16];
    
    for (i = 0; i < 4; i++) {
        for (j = 0; j < 4; j++) {
            aTmp[j * 4 + i] = 0.0;
            
            for (k = 0; k < 4; k++) {
                aTmp[j * 4 + i] += matrixA[k * 4 + i] * matrixB[j * 4 + k];
            }
        }
    }
    
    for (i = 0; i < 16; i++) {
        matrixC[i] = aTmp[i];
    }
}


// Apply a scaling transformation
void
scalePoseMatrix(float x, float y, float z, float* matrix)
{
    if (matrix) {
        // matrix * scale_matrix
        matrix[0]  *= x;
        matrix[1]  *= x;
        matrix[2]  *= x;
        matrix[3]  *= x;
        
        matrix[4]  *= y;
        matrix[5]  *= y;
        matrix[6]  *= y;
        matrix[7]  *= y;
        
        matrix[8]  *= z;
        matrix[9]  *= z;
        matrix[10] *= z;
        matrix[11] *= z;
    }
}


////////////////////////////////////////////////////////////////////////////////
// Draw the current frame using OpenGL
//
// This method is called by Vuforia when it wishes to render the current frame to
// the screen.
//
// *** Vuforia will call this method on a single background thread ***
- (void)renderFrameVuforia
{
    if (APPSTATUS_CAMERA_RUNNING == vUtils.appStatus) {
        [self setFramebuffer];
        Vuforia::Renderer& mRenderer = Vuforia::Renderer::getInstance();
        
        const Vuforia::State state = Vuforia::TrackerManager::getInstance().getStateUpdater().updateState();
        mRenderer.begin(state);
        
        // We must detect if background reflection is active and adjust the
        // culling direction.
        // If the reflection is active, this means the post matrix has been
        // reflected as well,
        // therefore standard counter clockwise face culling will result in
        // "inside out" models.
        if(Vuforia::Renderer::getInstance().getVideoBackgroundConfig().mReflection == Vuforia::VIDEO_BACKGROUND_REFLECTION_ON)
            glFrontFace(GL_CW);  //Front camera
        else
            glFrontFace(GL_CCW);   //Back camera
        
        if(self.currentRenderingPrimitives == nullptr)
            [self updateRenderingPrimitives];
        
        Vuforia::ViewList& viewList = self.currentRenderingPrimitives->getRenderingViews();
        
        // Clear colour and depth buffers
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
        
        glEnable(GL_DEPTH_TEST);
        glEnable(GL_CULL_FACE);
        glCullFace(GL_BACK);
        
        // Iterate over the ViewList
        for (int viewIdx = 0; viewIdx < viewList.getNumViews(); viewIdx++) {
            Vuforia::VIEW vw = viewList.getView(viewIdx);
            
            // Set up the viewport
            Vuforia::Vec4I viewport;
            // We're writing directly to the screen, so the viewport is relative to the screen
            viewport = self.currentRenderingPrimitives->getViewport(vw);
            
            // Set viewport for current view
            glViewport(viewport.data[0], viewport.data[1], viewport.data[2], viewport.data[3]);
            
            // Set scissor
            glScissor(viewport.data[0], viewport.data[1], viewport.data[2], viewport.data[3]);
            
            Vuforia::Matrix34F projMatrix = self.currentRenderingPrimitives->getProjectionMatrix(vw,
                                                                                    Vuforia::COORDINATE_SYSTEM_CAMERA);
            
            Vuforia::Matrix44F rawProjectionMatrixGL = Vuforia::Tool::convertPerspectiveProjection2GLMatrix(
                                                                                                            projMatrix,
                                                                                                            2.0,
                                                                                                            2500.0);
            
            // Apply the appropriate eye adjustment to the raw projection matrix, and assign to the global variable
            Vuforia::Matrix44F eyeAdjustmentGL = Vuforia::Tool::convert2GLMatrix(self.currentRenderingPrimitives->getEyeDisplayAdjustmentMatrix(vw));
            
            Vuforia::Matrix44F projectionMatrix;
            multiplyMatrix(&rawProjectionMatrixGL.data[0], &eyeAdjustmentGL.data[0], &projectionMatrix.data[0]);
            
            if (vw != Vuforia::VIEW_POSTPROCESS) {
                [self renderVideoBackground];
                renderDominoes(state, projectionMatrix);
            }
            
            glDisable(GL_SCISSOR_TEST);
            
        }
        
        mRenderer.end();
        
        [self presentFramebuffer];
    }
}


-(float) getSceneScaleFactor
{
    static const float VIRTUAL_FOV_Y_DEGS = 85.0f;
    
    // Get the y-dimension of the physical camera field of view
    Vuforia::Vec2F fovVector = Vuforia::CameraDevice::getInstance().getCameraCalibration().getFieldOfViewRads();
    float cameraFovYRads = fovVector.data[1];
    
    // Get the y-dimension of the virtual camera field of view
    float virtualFovYRads = VIRTUAL_FOV_Y_DEGS * M_PI / 180;
    
    // The scene-scale factor represents the proportion of the viewport that is filled by
    // the video background when projected onto the same plane.
    // In order to calculate this, let 'd' be the distance between the cameras and the plane.
    // The height of the projected image 'h' on this plane can then be calculated:
    //   tan(fov/2) = h/2d
    // which rearranges to:
    //   2d = h/tan(fov/2)
    // Since 'd' is the same for both cameras, we can combine the equations for the two cameras:
    //   hPhysical/tan(fovPhysical/2) = hVirtual/tan(fovVirtual/2)
    // Which rearranges to:
    //   hPhysical/hVirtual = tan(fovPhysical/2)/tan(fovVirtual/2)
    // ... which is the scene-scale factor
    return tan(cameraFovYRads / 2) / tan(virtualFovYRads / 2);
}


- (void) renderVideoBackground{
    // Use texture unit 0 for the video background - this will hold the camera frame and we want to reuse for all views
    // So need to use a different texture unit for the augmentation
    int vbVideoTextureUnit = 0;
    
    // Bind the video bg texture and get the Texture ID from Vuforia
    Vuforia::GLTextureUnit tex;
    tex.mTextureUnit = vbVideoTextureUnit;
    
    if (! Vuforia::Renderer::getInstance().updateVideoBackgroundTexture(&tex))
    {
        NSLog(@"Unable to bind video background texture!!");
        return;
    }
    
    Vuforia::Matrix44F vbProjectionMatrix = Vuforia::Tool::convert2GLMatrix(
                                                                            self.currentRenderingPrimitives->getVideoBackgroundProjectionMatrix(Vuforia::VIEW_SINGULAR, Vuforia::COORDINATE_SYSTEM_CAMERA));
    
    // Apply the scene scale on video see-through eyewear, to scale the video background and augmentation
    // so that the display lines up with the real world
    // This should not be applied on optical see-through devices, as there is no video background,
    // and the calibration ensures that the augmentation matches the real world
    if (Vuforia::Device::getInstance().isViewerActive())
    {
        float sceneScaleFactor = [self getSceneScaleFactor];
        scalePoseMatrix(sceneScaleFactor, sceneScaleFactor, 1.0f, vbProjectionMatrix.data);
    }
    
    glDisable(GL_DEPTH_TEST);
    glDisable(GL_CULL_FACE);
    glDisable(GL_SCISSOR_TEST);
    
    const Vuforia::Mesh& vbMesh = self.currentRenderingPrimitives->getVideoBackgroundMesh(Vuforia::VIEW_SINGULAR);
    // Load the shader and upload the vertex/texcoord/index data
    glUseProgram(self.vbShaderProgramID);
    glVertexAttribPointer(self.vbVertexHandle, 3, GL_FLOAT, false, 0, vbMesh.getPositionCoordinates());
    glVertexAttribPointer(self.vbTexCoordHandle, 2, GL_FLOAT, false, 0, vbMesh.getUVCoordinates());
    
    glUniform1i(self.vbTexSampler2DHandle, vbVideoTextureUnit);
    
    // Render the video background with the custom shader
    // First, we enable the vertex arrays
    glEnableVertexAttribArray(self.vbVertexHandle);
    glEnableVertexAttribArray(self.vbTexCoordHandle);
    
    // Pass the projection matrix to OpenGL
    glUniformMatrix4fv(self.vbProjectionMatrixHandle, 1, GL_FALSE, vbProjectionMatrix.data);
    
    // Then, we issue the render call
    glDrawElements(GL_TRIANGLES, vbMesh.getNumTriangles() * 3, GL_UNSIGNED_SHORT,
                   vbMesh.getTriangles());
    
    // Finally, we disable the vertex arrays
    glDisableVertexAttribArray(self.vbVertexHandle);
    glDisableVertexAttribArray(self.vbTexCoordHandle);
    
    ShaderUtils::checkGlError("Rendering of the video background failed");
}



////////////////////////////////////////////////////////////////////////////////
// Callback function called by the tracker when each tracking cycle has finished
void VirtualButton_UpdateCallback::Vuforia_onUpdate(Vuforia::State& state)
{
    // Process the virtual button
    virtualButtonOnUpdate(state);
}

@end
