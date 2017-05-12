/*===============================================================================
Copyright (c) 2016 PTC Inc. All Rights Reserved.

Copyright (c) 2012-2015 Qualcomm Connected Experiences, Inc. All Rights Reserved.

Vuforia is a trademark of PTC Inc., registered in the United States and other 
countries.
===============================================================================*/


#ifndef _VUFORIA_TRANSITION_3D_TO_2D_H_
#define _VUFORIA_TRANSITION_3D_TO_2D_H_

#include <OpenGLES/ES2/gl.h>
#include <OpenGLES/ES2/glext.h>
#include <Vuforia/Vuforia.h>
#include <Vuforia/Renderer.h>
#include <Vuforia/Image.h>

class Transition3Dto2D
{
public:
    
    Transition3Dto2D(int screenWidth, int screenHeight, bool isPortraitMode);
    ~Transition3Dto2D();
    
    // Call this from the GL thread
    void initializeGL(unsigned int sProgramID);
    
    // Center of the screen is (0, 0)
    // centerX and centerY are pixel offsets from this point
    // width and height are also in pixels
    void setScreenRect(int centerX, int centerY, int width, int height);
    
    // Call this once to set up the transition
    // Note: inReverse and keepRendering are not currently used
    void startTransition(float duration, bool inReverse, bool keepRendering);
    
    // Transitions between textures 1 and 2
    // Transitions between target space and screen space
    void render(Vuforia::Matrix44F projectionMatrix, Vuforia::Matrix34F targetPose, Vuforia::Vec2F trackableSize, GLuint texture1);
    
    // Returns true if transition has finished animating
    bool transitionFinished();
    
private:
    

    bool isActivityPortraitMode;
    int screenWidth;
    int screenHeight;
    Vuforia::Vec4F screenRect;
    Vuforia::Matrix44F identityMatrix;
    Vuforia::Matrix44F orthoMatrix;
    
    unsigned int shaderProgramID;
    GLint normalHandle;
    GLint vertexHandle;
    GLint textureCoordHandle;
    GLint mvpMatrixHandle;

    
    float animationLength;
    int animationDirection;
    bool renderAfterCompletion;
    
    unsigned long animationStartTime;
    bool animationFinished;
    
    float stepTransition();
    Vuforia::Matrix44F getFinalPositionMatrix();
    float deccelerate(float val);
    float accelerate(float val);
    void linearInterpolate(Vuforia::Matrix44F* start, Vuforia::Matrix44F* end, Vuforia::Matrix44F* current, float elapsed);
    unsigned long getCurrentTimeMS();
    void updateScreenProperties(int screenWidth, int screenHeight, bool isPortraitMode);    
};

#endif //_VUFORIA_TRANSITION_3D_TO_2D_H_
