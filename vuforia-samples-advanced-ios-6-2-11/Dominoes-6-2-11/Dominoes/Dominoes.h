/*===============================================================================
Copyright (c) 2016 PTC Inc. All Rights Reserved.

Copyright (c) 2012-2014 Qualcomm Connected Experiences, Inc. All Rights Reserved.

Vuforia is a trademark of PTC Inc., registered in the United States and other 
countries.
===============================================================================*/

#ifndef _DOMINOES_H_
#define _DOMINOES_H_

#import <stdio.h>
#import <string.h>
#import <assert.h>
#import <sys/time.h>
#import <math.h>
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>
#import <Vuforia/Vuforia.h>
#import <Vuforia/UpdateCallback.h>
#import <Vuforia/CameraDevice.h>
#import <Vuforia/Renderer.h>
#import <Vuforia/VideoBackgroundConfig.h>
#import <Vuforia/Trackable.h>
#import <Vuforia/TrackableResult.h>
#import <Vuforia/ImageTargetResult.h>
#import <Vuforia/VirtualButtonResult.h>
#import <Vuforia/Tool.h>
#import <Vuforia/Tracker.h>
#import <Vuforia/CameraCalibration.h>
#import <Vuforia/ImageTarget.h>
#import <Vuforia/VirtualButton.h>
#import <Vuforia/Rectangle.h>

#import "Cube.h"
#import "ShaderUtils.h"
#import "SampleMath.h"
#import "Texture.h"
#import "ButtonOverlayViewController.h"


#define MAX_DOMINOES 100
#define DOMINO_TILT_SPEED 300.0f
#define MAX_TAP_TIMER 200
#define MAX_TAP_DISTANCE2 400


enum ActionType {
    ACTION_DOWN,
    ACTION_MOVE,
    ACTION_UP,
    ACTION_CANCEL
};

enum DominoState {
    DOMINO_STANDING,
    DOMINO_FALLING,
    DOMINO_RESTING
};


typedef struct _TouchEvent {
    bool isActive;
    int actionType;
    int pointerId;
    float x;
    float y;
    float lastX;
    float lastY;
    float startX;
    float startY;
    float tapX;
    float tapY;
    unsigned long startTime;
    unsigned long dt;
    float dist2;
    bool didTap;
} TouchEvent;

typedef struct _LLNode {
    int id;
    _LLNode* next;
} LLNode;

typedef struct _Domino {
    int id;
    int state;
    
    LLNode* neighborList;
    
    Vuforia::Vec2F position;
    float pivotAngle;
    float tiltAngle;
    Vuforia::Matrix44F transform;
    Vuforia::Matrix44F pickingTransform;
    
    int tippedBy;
    int restingFrameCount;
} Domino;


void dominoesSetButtonOverlay(ButtonOverlayViewController* overlay);
void dominoesSetTextures(NSArray* t);
void dominoesSetShaderProgramID(int spid);
void dominoesSetVertexHandle(int vh);
void dominoesSetNormalHandle(int nh);
void dominoesSetTextureCoordHandle(int tch);
void dominoesSetMvpMatrixHandle(int mmh);
void dominoesSetTexSampler2DHandle(int t2dh);

void initializeDominoes();
bool dominoesIsSimulating();
bool dominoesHasDominoes();
bool dominoesHasRun();

void renderDominoes(const Vuforia::State& state, Vuforia::Matrix44F& projectionMatrix);
void dominoesTouchEvent(int actionType, int pointerId, float x, float y);
void dominoesStart();
void dominoesReset();
void dominoesClear();
void dominoesDelete();

void virtualButtonOnUpdate(Vuforia::State& state);

void initSoundEffect();
void playSoundEffect();
void showDeleteButton();
void hideDeleteButton();
void displayMessage(const char* message);

void updateAugmentation(const Vuforia::Trackable* trackable, float dt);
void handleTouches();
void renderAugmentation(const Vuforia::Trackable* trackable);
void renderCube(float* transform);

void addVirtualButton();
void removeVirtualButton();
void moveVirtualButton(Domino* domino);
void enableVirtualButton();
void disableVirtualButton();

void initDominoBaseVertices();
void initDominoNormals();

bool canDropDomino(Vuforia::Vec2F position);
void dropDomino(Vuforia::Vec2F position);
void updateDominoTransform(Domino* domino);
void updatePickingTransform(Domino* domino);

bool runSimulation(Domino* domino, float dt);
void handleCollision(Domino* domino, Domino* otherDomino, float originalTilt);
void adjustPivot(Domino* domino, Domino* otherDomino);
Domino* getDominoById(int id);

void resetDominoes();
void clearDominoes();
void setSelectedDomino(Domino* domino);
void deleteSelectedDomino();

void projectScreenPointToPlane(Vuforia::Vec2F point, Vuforia::Vec3F planeCenter, Vuforia::Vec3F planeNormal,
                               Vuforia::Vec3F &intersection, Vuforia::Vec3F &lineStart, Vuforia::Vec3F &lineEnd);
bool linePlaneIntersection(Vuforia::Vec3F lineStart, Vuforia::Vec3F lineEnd, Vuforia::Vec3F pointOnPlane,
                           Vuforia::Vec3F planeNormal, Vuforia::Vec3F &intersection);

bool checkIntersection(Vuforia::Matrix44F transformA, Vuforia::Matrix44F transformB);
bool isSeparatingAxis(Vuforia::Vec3F axis);

bool checkIntersectionLine(Vuforia::Matrix44F transformA, Vuforia::Vec3F pointA, Vuforia::Vec3F pointB);
bool isSeparatingAxisLine(Vuforia::Vec3F axis, Vuforia::Vec3F pointA, Vuforia::Vec3F pointB);

unsigned long getCurrentTimeMS();

#endif // _DOMINOES_H_
