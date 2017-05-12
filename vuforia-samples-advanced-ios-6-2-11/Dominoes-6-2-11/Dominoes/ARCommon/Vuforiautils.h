/*===============================================================================
Copyright (c) 2015-2016 PTC Inc. All Rights Reserved.

Copyright (c) 2012-2014 Qualcomm Connected Experiences, Inc. All Rights Reserved.

Vuforia is a trademark of PTC Inc., registered in the United States and other 
countries.
===============================================================================*/

#import <Foundation/Foundation.h>
#import <Vuforia/Tool.h>
#import <Vuforia/DataSet.h>
#import <Vuforia/ImageTarget.h>
#import <Vuforia/CameraDevice.h>
#import <Vuforia/TrackableResult.h>
#import "Texture.h"

// Target type - used by the app to tell Vuforia its intent
typedef enum typeOfTarget {
    TYPE_IMAGETARGETS,
    TYPE_MULTITARGETS
} TargetType;

// Application status - used by Vuforia initialisation
typedef enum _status {
    APPSTATUS_UNINITED,
    APPSTATUS_INIT_APP,
    APPSTATUS_INIT_VUFORIA,
    APPSTATUS_INIT_TRACKER,
    APPSTATUS_INIT_APP_AR,
    APPSTATUS_LOAD_TRACKER,
    APPSTATUS_INITED,
    APPSTATUS_CAMERA_STOPPED,
    APPSTATUS_CAMERA_RUNNING,
    APPSTATUS_ERROR
} status;

// Local error codes - offset by -1000 to allow for Vuforia::init() error codes in Vuforia.h
enum _errorCode {
    VUFORIA_ERRCODE_INIT_TRACKER = -1000,
    VUFORIA_ERRCODE_CREATE_DATASET = -1001,
    VUFORIA_ERRCODE_LOAD_DATASET = -1002,
    VUFORIA_ERRCODE_ACTIVATE_DATASET = -1003,
    VUFORIA_ERRCODE_DEACTIVATE_DATASET = -1004,
    VUFORIA_ERRCODE_DESTROY_DATASET = -1005,
    VUFORIA_ERRCODE_LOAD_TARGET = -1006,
    VUFORIA_ERRCODE_NO_NETWORK_CONNECTION = -1007,
    VUFORIA_ERRCODE_NO_SERVICE_AVAILABLE = -1008
};

#pragma mark --- Class interface for DataSet list ---
@interface DataSetItem : NSObject
{
@protected
    NSString *name;
    NSString *path;
    Vuforia::DataSet *dataSet;
}

@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *path;
@property (nonatomic) Vuforia::DataSet *dataSet;

- (id) initWithName:(NSString *)theName andPath:(NSString *)thePath;

@end


#pragma mark --- Class interface ---

@interface Vuforiautils : NSObject <UIAlertViewDelegate>
{
@public
    CGSize viewSize;            // set in initialisation
    
    CGFloat contentScalingFactor; // 1.0 normal, 2.0 for retina enabled
    NSMutableArray *targetsList;       // Array of DataSetItem - load target from this list of resources
    int VuforiaFlags;              // Vuforia initialisation flags
    status appStatus;           // Current app status
    NSInteger errorCode;              // if appStatus == APPSTATUS_ERROR
    
    TargetType targetType;      // for app to inform Vuforiautils
    
    struct Viewport {        // shared between users of Vuforiautils
        int posX;
        int posY;
        int sizeX;
        int sizeY;
    };
    
    BOOL videoStreamStarted;    // becomes true at first "camera is running"
    BOOL isVisualSearchOn;
    BOOL vsAutoControlEnabled;
    NSInteger noOfCameras;
    BOOL orientationChanged;
    UIInterfaceOrientation orientation;
    
@private
    Vuforia::DataSet * currentDataSet; // the loaded DataSet
    BOOL cameraTorchOn;
    BOOL cameraContinuousAFOn;
    
@protected
    Vuforia::CameraDevice::CAMERA_DIRECTION activeCamera;
}

@property (nonatomic) CGSize viewSize;
@property (nonatomic, weak) id delegate;

@property (nonatomic) CGFloat contentScalingFactor;
@property (nonatomic, strong) NSMutableArray *targetsList;
@property (nonatomic) int VuforiaFlags;           
@property (nonatomic) status appStatus;        
@property (nonatomic) NSInteger errorCode;
@property (nonatomic) NSInteger noOfCameras;
@property (nonatomic) TargetType targetType;
@property (nonatomic) Viewport viewport;

@property (nonatomic) BOOL videoStreamStarted;

@property (nonatomic, readonly) BOOL cameraTorchOn;
@property (nonatomic, readonly) BOOL cameraContinuousAFOn;
@property (nonatomic) BOOL isVisualSearchOn;
@property (nonatomic) BOOL vsAutoControlEnabled;

@property (readwrite) BOOL orientationChanged;
@property (readwrite) UIInterfaceOrientation orientation;

@property (nonatomic, readonly) Vuforia::CameraDevice::CAMERA_DIRECTION activeCamera;

#pragma mark --- Class Methods ---

+ (Vuforiautils *) getInstance;

- (void)initApplication;
- (void)initApplicationAR;
- (void)postInitVuforia;

- (void)restoreCameraSettings;

- (void)createARofSize:(CGSize)theSize forDelegate:(id)theDelegate;
- (void)destroyAR;
- (void)pauseAR;
- (void)resumeAR;

- (void) addTargetName:(NSString *)theName atPath:(NSString *)thePath;

- (BOOL)unloadDataSet:(Vuforia::DataSet *)theDataSet;
- (Vuforia::DataSet *)loadDataSet:(NSString *)dataSetPath;
- (BOOL)deactivateDataSet:(Vuforia::DataSet *)theDataSet;
- (BOOL)activateDataSet:(Vuforia::DataSet *)theDataSet;
- (void) allowDataSetModification;
- (void) saveDataSetModifications;

- (Vuforia::ImageTarget *) findImageTarget:(const char *) name;
- (Vuforia::MultiTarget *) findMultiTarget;
- (Vuforia::ImageTarget *) getImageTarget:(int)itemNo;

- (void)cameraSetTorchMode:(BOOL)switchOn;
- (void)cameraSetContinuousAFMode:(BOOL)switchOn;
- (void)cameraTriggerAF;
- (void)cameraCancelAF;
- (void)cameraPerformAF;
- (NSMutableArray*) loadTextures:(NSArray*)textureList;
- (Texture *) createTexture:(NSString*)fileName;
- (void) configureVideoBackground;
@end

extern Vuforiautils *vUtils;
