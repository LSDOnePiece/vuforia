/*===============================================================================
Copyright (c) 2015-2016 PTC Inc. All Rights Reserved.

Copyright (c) 2012-2014 Qualcomm Connected Experiences, Inc. All Rights Reserved.

Vuforia is a trademark of PTC Inc., registered in the United States and other 
countries.
===============================================================================*/

#import "Vuforiautils.h"
#import <Vuforia/Vuforia.h>
#import <Vuforia/Vuforia_iOS.h>
#import <Vuforia/Renderer.h>
#import <Vuforia/Tracker.h>
#import <Vuforia/TrackerManager.h>
#import <Vuforia/ObjectTracker.h>
#import <Vuforia/VideoBackgroundConfig.h>
#import <Vuforia/MultiTarget.h>

static NSString* const DatasetErrorTitle = @"Dataset Error";

@interface Vuforiautils()
- (void)updateApplicationStatus:(status)newStatus;
- (void)bumpAppStatus;
- (void)initVuforia;
- (int)initTracker;
- (void)loadTracker;
- (void)startCamera;
- (void)stopCamera;
- (void)configureVideoBackground;
- (void)cameraDidStart;
- (void)cameraDidStop;
@end

Vuforiautils *vUtils = nil; // singleton class

#pragma mark --- Class interface for DataSet list ---
@implementation DataSetItem

@synthesize name;
@synthesize path;
@synthesize dataSet;

- (id) initWithName:(NSString *)theName andPath:(NSString *)thePath
{
    self = [super init];
    if (self) {
        name = [theName copy]; // copy string
        path = [thePath copy]; // copy string
        dataSet = nil;
    }
    return self;    
}

@end

#pragma mark --- Class implementation ---

@implementation Vuforiautils

@synthesize viewSize;
@synthesize delegate;

@synthesize contentScalingFactor;
@synthesize targetsList;
@synthesize VuforiaFlags;           
@synthesize appStatus;        
@synthesize errorCode;

@synthesize targetType;
@synthesize viewport;

@synthesize videoStreamStarted;

@synthesize noOfCameras, activeCamera, cameraTorchOn, cameraContinuousAFOn;

@synthesize isVisualSearchOn,vsAutoControlEnabled, orientationChanged;

@synthesize orientation;

// initialise Vuforiautils
- (id) init
{
    if ((self = [super init]) != nil)
    {
        currentDataSet = nil;
        contentScalingFactor = 1.0f; // non-Retina is default
        appStatus = APPSTATUS_UNINITED;
        viewSize = [[UIScreen mainScreen] bounds].size; // set as full screen
        
        targetType = TYPE_IMAGETARGETS;
        targetsList = [[NSMutableArray alloc] init];
        
        // Initial camera settings
        cameraTorchOn = NO;
        cameraContinuousAFOn = YES;
        videoStreamStarted = NO;
        // Select the camera to open, set this to Vuforia::CameraDevice::CAMERA_DIRECTION_FRONT 
        // to activate the front camera instead.
        activeCamera = Vuforia::CameraDevice::CAMERA_DIRECTION_BACK;
        noOfCameras = 1;
    }
    
    return self;
}


// return Vuforiautils singleton, initing if necessary
+ (Vuforiautils *) getInstance
{
    if (vUtils == nil)
    {
        vUtils = [[Vuforiautils alloc] init];
    }
        
    return vUtils;
}


// discard resources
- (void)dealloc {
    targetsList = nil;
}


- (void) addTargetName:(NSString *)theName atPath:(NSString *)thePath
{
    DataSetItem *dataSet = [[DataSetItem alloc] initWithName:theName andPath:thePath];
    if (dataSet != nil)
        [targetsList addObject:dataSet];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (![[alertView title] isEqualToString:DatasetErrorTitle]) {
        exit(0);
    }
}


- (void)restoreCameraSettings
{
    [self cameraSetTorchMode:cameraTorchOn];
    [self cameraSetContinuousAFMode:cameraContinuousAFOn];
}


- (void)cameraSetTorchMode:(BOOL)switchOn
{
    bool switchTorchOn = YES == switchOn ? true : false;
    
    if (true == Vuforia::CameraDevice::getInstance().setFlashTorchMode(switchTorchOn))
    {
        cameraTorchOn = switchOn;
    }
}


- (void)cameraSetContinuousAFMode:(BOOL)switchOn
{
    int focusMode = YES == switchOn ? Vuforia::CameraDevice::FOCUS_MODE_CONTINUOUSAUTO : Vuforia::CameraDevice::FOCUS_MODE_NORMAL;
    
    if (true == Vuforia::CameraDevice::getInstance().setFocusMode(focusMode))
    {
        cameraContinuousAFOn = switchOn;
    }
}


- (void)cameraTriggerAF
{
    [self performSelector:@selector(cameraPerformAF) withObject:nil afterDelay:.4];
}

- (void)cameraPerformAF
{
    if (true == Vuforia::CameraDevice::getInstance().setFocusMode(Vuforia::CameraDevice::FOCUS_MODE_TRIGGERAUTO))
    {
        cameraContinuousAFOn = NO;
    }
}

- (void)cameraCancelAF
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(cameraPerformAF) object:nil];
}

#pragma mark --- external control of Vuforia ---

////////////////////////////////////////////////////////////////////////////////
// create the Augmented Reality context
- (void)createARofSize:(CGSize)theSize forDelegate:(id)theDelegate
{
    NSLog(@"Vuforiautils onCreate()");
    
    if (appStatus != APPSTATUS_UNINITED)
        return;
    
    // to initialise Vuforia we need the view size and a class for optional callbacks
    viewSize = theSize;
    delegate = theDelegate;

    // start the initialisation sequence here...
    [vUtils updateApplicationStatus:APPSTATUS_INIT_APP];
}


////////////////////////////////////////////////////////////////////////////////
// destroy the Augmented Reality context
- (void)destroyAR
{
    NSLog(@"Vuforiautils onDestroy()");
    
    // Deinitialise Vuforia SDK
    if (appStatus != APPSTATUS_UNINITED)
    {
        // deactivate the dataset and unload any pre-loaded datasets
        [self deactivateDataSet:currentDataSet];

        // Unload all the requested datasets
        for (DataSetItem *aDataSet in targetsList)
        {
            if (aDataSet.dataSet != nil)
            {
                [self unloadDataSet:aDataSet.dataSet];
                aDataSet.dataSet = nil;
            }
        }
        
        Vuforia::deinit();
    }
    
    appStatus = APPSTATUS_UNINITED;
}


////////////////////////////////////////////////////////////////////////////////
// pause the camera view and the tracking of targets
- (void)pauseAR
{
    NSLog(@"Vuforiautils onPause()");
    
    // If the app status is APPSTATUS_CAMERA_RUNNING, Vuforia must have been fully
    // initialised
    if (APPSTATUS_CAMERA_RUNNING == vUtils.appStatus) {
        [vUtils updateApplicationStatus:APPSTATUS_CAMERA_STOPPED];
        
        // Vuforia-specific pause operation
        Vuforia::onPause();
    }
}


////////////////////////////////////////////////////////////////////////////////
// resume the camera view and tracking of targets
- (void)resumeAR
{
    NSLog(@"Vuforiautils onResume()");
    
    // If the app status is APPSTATUS_CAMERA_STOPPED, Vuforia must have been fully
    // initialised
    if (APPSTATUS_CAMERA_STOPPED == vUtils.appStatus) {
        // Vuforia-specific resume operation
        Vuforia::onResume();
        
        [vUtils updateApplicationStatus:APPSTATUS_CAMERA_RUNNING];
    }
}


#pragma mark --- Vuforia initialisation ---
////////////////////////////////////////////////////////////////////////////////
- (void)updateApplicationStatus:(status)newStatus
{
    if (newStatus != appStatus && APPSTATUS_ERROR != appStatus) {
        appStatus = newStatus;
        
        switch (appStatus) {
            case APPSTATUS_INIT_APP:
                NSLog(@"APPSTATUS_INIT_APP");
                // Initialise the application
                [self initApplication];
                [self updateApplicationStatus:APPSTATUS_INIT_VUFORIA];
                break;
                
            case APPSTATUS_INIT_VUFORIA:
                NSLog(@"APPSTATUS_INIT_VUFORIA");
                // Initialise Vuforia
                [self performSelectorInBackground:@selector(initVuforia) withObject:nil];
                break;
                
            case APPSTATUS_INIT_TRACKER:
                NSLog(@"APPSTATUS_INIT_TRACKER");
                // Initialise the tracker
                if ([self initTracker] > 0) {
                    [self updateApplicationStatus: APPSTATUS_INIT_APP_AR];
                }
                break;                
                
            case APPSTATUS_INIT_APP_AR:
                NSLog(@"APPSTATUS_INIT_APP_AR");
                // AR-specific initialisation
                [self initApplicationAR];
                
                [self updateApplicationStatus:APPSTATUS_LOAD_TRACKER];
                break;                
                
            case APPSTATUS_LOAD_TRACKER:
                NSLog(@"APPSTATUS_LOAD_TRACKER");
                // Load tracker data
                [self performSelectorInBackground:@selector(loadTracker) withObject:nil];
                
                break;
                
            case APPSTATUS_INITED:
                NSLog(@"APPSTATUS_INITED");
                // Tasks for after Vuforia inited but before camera starts running
                Vuforia::onResume(); // ensure it's called first time in
                [self postInitVuforia];
                
                [self updateApplicationStatus:APPSTATUS_CAMERA_RUNNING];
                break;
                
            case APPSTATUS_CAMERA_RUNNING:
                NSLog(@"APPSTATUS_CAMERA_RUNNING");
                // Start the camera and tracking
                [self startCamera];
                videoStreamStarted = YES;
                [self cameraDidStart];
                break;
                
            case APPSTATUS_CAMERA_STOPPED:
                NSLog(@"APPSTATUS_CAMERA_STOPPED");
                // Stop the camera and tracking
                [self stopCamera];
                [self cameraDidStop];
                break;
                
            default:
                NSLog(@"updateApplicationStatus: invalid app status");
                break;
        }
    }
    
    if (APPSTATUS_ERROR == appStatus) {
        // Application initialisation failed, display an alert view
        UIAlertView* alert;
        		
        NSString *appName = [[[NSBundle mainBundle] infoDictionary] objectForKey:(NSString*)kCFBundleNameKey];
        NSString *cameraAccessMsg = [NSString stringWithFormat:@"User denied camera access to this App. To restore camera access, go to: \nSettings > Privacy > Camera > %@ and turn it ON.", appName];
        const char *msgNoCamera = [cameraAccessMsg cStringUsingEncoding:NSUTF8StringEncoding];
        const char *msgDevice = "Failed to initialize Vuforia because this device is not supported.";
        const char *msgDefault = "Application initialisation failed.";
        const char* msgNoNetwork = "Failed to initialize Visual Search because the device has no network connection.";
        const char* msgNoService = "Failed to initialize Visual Search because the service is not available.";

        const char *msg = msgDefault;
        
        switch (errorCode) {
            case VUFORIA_ERRCODE_NO_NETWORK_CONNECTION:
                msg = msgNoNetwork;
                break;
            case VUFORIA_ERRCODE_NO_SERVICE_AVAILABLE:
                msg = msgNoService;
                break;
            case Vuforia::INIT_NO_CAMERA_ACCESS:
                msg = msgNoCamera;
                break;
            case Vuforia::INIT_DEVICE_NOT_SUPPORTED:
                msg = msgDevice;
                break;
                
            case Vuforia::INIT_LICENSE_ERROR_NO_NETWORK_TRANSIENT:
                msg = "Unable to contact server. Please try again later.";
                break;
                        
            case Vuforia::INIT_LICENSE_ERROR_NO_NETWORK_PERMANENT:
                msg = "No network available. Please make sure you are connected to the Internet.";
                break;
                
            case Vuforia::INIT_LICENSE_ERROR_INVALID_KEY:
                msg = "Invalid Key used. Please make sure you are using a valid Vuforia App Key.";
                break;
                
            case Vuforia::INIT_LICENSE_ERROR_CANCELED_KEY:
                msg = "This app license key has been canceled and may no longer be used. Please get a new license key.";
                break;
                
            case Vuforia::INIT_LICENSE_ERROR_MISSING_KEY:
                msg = "Vuforia App key is missing. Please get a valid key, by logging into your account at developer.vuforia.com and creating a new project.";
                break;

            case Vuforia::INIT_LICENSE_ERROR_PRODUCT_TYPE_MISMATCH:
                msg = "Vuforia App key is not valid for this product. Please get a valid key, by logging into your account at developer.vuforia.com and choosing the right product type during project creation.";
                break;

            case Vuforia::INIT_ERROR:
            case VUFORIA_ERRCODE_INIT_TRACKER:
            case VUFORIA_ERRCODE_CREATE_DATASET:
            case VUFORIA_ERRCODE_LOAD_DATASET:
            case VUFORIA_ERRCODE_ACTIVATE_DATASET:
            case VUFORIA_ERRCODE_DEACTIVATE_DATASET:
            default:
                break;
        }
        
        alert = [[UIAlertView alloc] initWithTitle:@"Error" message:[NSString stringWithUTF8String:msg] delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
        
        [alert show];
    }
}


////////////////////////////////////////////////////////////////////////////////
// Bump the application status on one step
- (void)bumpAppStatus
{
    [self updateApplicationStatus:(status)(appStatus + 1)];
}


////////////////////////////////////////////////////////////////////////////////
// Initialise the application
- (void)initApplication
{
    // Inform Vuforia that the drawing surface has been created
    Vuforia::onSurfaceCreated();
    
    // Invoke optional application initialisation in the delegate class
    if ((delegate != nil) && [delegate respondsToSelector:@selector(initApplication)])
        [delegate performSelectorOnMainThread:@selector(initApplication) withObject:nil waitUntilDone:YES];
}


////////////////////////////////////////////////////////////////////////////////
// Initialise Vuforia [performed on a background thread]
- (void)initVuforia
{
    // Background thread must have its own autorelease pool
    @autoreleasepool {
    Vuforia::setInitParameters(VuforiaFlags,"AeGYQbH/////AAAAGVR4Cur1nEZJtcEP9dtFLFc4c5PJFfIQT1OIcZmFbB6AhjlJyUW8AXEIUnGEPCixAcPGdkjvTWmzjiHh0MvRsbHsvy1DJyN9M7GNiT4APTOR7yrUsRF3+cFfwm4bVT+GfwHgDnbYriQbTMQfJIyd28eQKdp8YK/4h3Gm7u6F2mpYbJqltY7ygVGdygGkyznc+nXzU3BNfr0Mkq+yKL0Ht0H9Nc8cZottiJ72xQYSuZhcvgFq2/DVfRauUi7YNS9nwR6j07EymrEGGe9G8lIOp49RapF7GZTDa24HU92vQhyfEfNeLI4/ilSUFB/UKnL0WgadjgsvKlzPiBQF98zllRzZNPPdFu8DE+IJn+RNTQ7k");
    
    // Vuforia::init() will return positive numbers up to 100 as it progresses towards success
    // and negative numbers for error indicators
    NSInteger initSuccess = 0;
    do {
        initSuccess = Vuforia::init();
    } while (0 <= initSuccess && 100 > initSuccess);
    
    if (initSuccess != 100) {
        appStatus = APPSTATUS_ERROR;
        errorCode = initSuccess;
    }    

    // Continue execution on the main thread
    [self performSelectorOnMainThread:@selector(bumpAppStatus) withObject:nil waitUntilDone:NO];
    }
} 


////////////////////////////////////////////////////////////////////////////////
// Initialise the AR parts of the application
- (void)initApplicationAR
{
    // Invoke optional AR initialisation in the delegate class
    if ((delegate != nil) && [delegate respondsToSelector:@selector(initApplicationAR)])
        [delegate performSelectorOnMainThread:@selector(initApplicationAR) withObject:nil waitUntilDone:YES];
}


//////////////////////////////////////////////////////////////////////////////////
// Initialise the tracker [performed on a background thread]
- (int)initTracker
{
    int res = 0;
    
    // Initialize the image tracker
    Vuforia::TrackerManager& trackerManager = Vuforia::TrackerManager::getInstance();
    
    // Image Tracker...
    Vuforia::Tracker* trackerBase = trackerManager.initTracker(Vuforia::ObjectTracker::getClassType());
    if (trackerBase == NULL)
    {
        NSLog(@"Failed to initialize ObjectTracker.");
    }
    else
    {
        NSLog(@"Successfully initialized ObjectTracker.");
        res = 1;
    }

    if (res == 0)
    {
        appStatus = APPSTATUS_ERROR;
        errorCode = VUFORIA_ERRCODE_INIT_TRACKER;
    }
    
    return res;
}


////////////////////////////////////////////////////////////////////////////////
// Load the tracker data [performed on a background thread]
- (void)loadTracker
{
    // Background thread must have its own autorelease pool
    @autoreleasepool {
    BOOL haveLoadedOneDataSet = NO;
    
    // Load all the requested datasets
    for (DataSetItem *aDataSet in targetsList)
    {
        if (aDataSet.path != nil)
        {
            aDataSet.dataSet = [self loadDataSet:aDataSet.path];
            if (haveLoadedOneDataSet == NO)
            {
                if (aDataSet.dataSet != nil)
                {
                    // activate the first one in the list
                    [self activateDataSet:aDataSet.dataSet];
                    haveLoadedOneDataSet = YES;
                }
            }
        }
    }
    
    // Check that we've loaded at least one target
    if (!haveLoadedOneDataSet)
    {
        NSLog(@"Vuforiautils: Failed to load any target");
        appStatus = APPSTATUS_ERROR;
        errorCode = VUFORIA_ERRCODE_LOAD_TARGET;
    }

    // Continue execution on the main thread
    if (appStatus != APPSTATUS_ERROR)
        [self performSelectorOnMainThread:@selector(bumpAppStatus) withObject:nil waitUntilDone:NO];
        
    }
}


////////////////////////////////////////////////////////////////////////////////
// Start capturing images from the camera
- (void)startCamera
{
    // Initialise the camera
    if (Vuforia::CameraDevice::getInstance().init(activeCamera)) {
        //// Select the default mode - given as example of how and where to set the Camera mode
        //if (Vuforia::CameraDevice::getInstance().selectVideoMode(Vuforia::CameraDevice::MODE_DEFAULT)) {
        
        // Configure video background
        [self configureVideoBackground];
        
        // Start camera capturing
        if (Vuforia::CameraDevice::getInstance().start()) {
            // Start the tracker
            Vuforia::TrackerManager& trackerManager = Vuforia::TrackerManager::getInstance();
            Vuforia::Tracker* tracker = trackerManager.getTracker(Vuforia::ObjectTracker::getClassType());
            if(tracker != 0)
                tracker->start();
        }
        
        // Restore camera settings
        [self restoreCameraSettings];
    }
}


////////////////////////////////////////////////////////////////////////////////
// Stop capturing images from the camera
- (void)stopCamera
{
    // Stop the tracker:
    Vuforia::TrackerManager& trackerManager = Vuforia::TrackerManager::getInstance();
    Vuforia::Tracker* tracker = trackerManager.getTracker(Vuforia::ObjectTracker::getClassType());
    if(tracker != 0)
        tracker->stop();
    
    Vuforia::CameraDevice::getInstance().stop();
    Vuforia::CameraDevice::getInstance().deinit();
}



////////////////////////////////////////////////////////////////////////////////
// Do the things that need doing after initialisation
- (void)postInitVuforia
{
    // Get the device screen dimensions, allowing for hi-res mode
    viewSize.width *= contentScalingFactor; // set by the view initialisation before Vuforia initialisation
    viewSize.height *= contentScalingFactor;
    
    // Inform Vuforia that the drawing surface size has changed
    Vuforia::onSurfaceChanged(viewSize.height, viewSize.width);
    
    // let the delegate handle this if wanted
    if ((delegate != nil) && [delegate respondsToSelector:@selector(postInitVuforia)])
        [delegate performSelectorOnMainThread:@selector(postInitVuforia) withObject:nil waitUntilDone:YES];
}


////////////////////////////////////////////////////////////////////////////////
// Perform actions following the camera starting
- (void)cameraDidStart
{
    // Inform the delegate
    if ((delegate != nil) && [delegate respondsToSelector:@selector(cameraDidStart)]) {
        [delegate performSelectorOnMainThread:@selector(cameraDidStart) withObject:nil waitUntilDone:YES];
    }
}


////////////////////////////////////////////////////////////////////////////////
// Perform actions following the camera stopping
- (void)cameraDidStop
{
    // Inform the delegate
    if ((delegate != nil) && [delegate respondsToSelector:@selector(cameraDidStop)]) {
        [delegate performSelectorOnMainThread:@selector(cameraDidStop) withObject:nil waitUntilDone:YES];
    }
}


////////////////////////////////////////////////////////////////////////////////
// Configure the video background
- (void)configureVideoBackground
{
    // Get the default video mode
    Vuforia::CameraDevice& cameraDevice = Vuforia::CameraDevice::getInstance();
    Vuforia::VideoMode videoMode = cameraDevice.getVideoMode(Vuforia::CameraDevice::MODE_DEFAULT);
    
    // Configure the video background
    Vuforia::VideoBackgroundConfig config;
    config.mEnabled = true;
    config.mPosition.data[0] = 0.0f;
    config.mPosition.data[1] = 0.0f;
    
    // Compare aspect ratios of video and screen.  If they are different
    // we use the full screen size while maintaining the video's aspect
    // ratio, which naturally entails some cropping of the video.
    // Note - screenRect is portrait but videoMode is always landscape,
    // which is why "width" and "height" appear to be reversed.
    float arVideo = (float)videoMode.mWidth / (float)videoMode.mHeight;
    float arScreen = viewSize.height / viewSize.width;
    
    int width = (int)viewSize.height;
    int height = (int)viewSize.width;
    
    if (arVideo > arScreen)
    {
        // Video mode is wider than the screen.  We'll crop the left and right edges of the video
        config.mSize.data[0] = (int)viewSize.width * arVideo;
        config.mSize.data[1] = (int)viewSize.width;
    }
    else
    {
        // Video mode is taller than the screen.  We'll crop the top and bottom edges of the video.
        // Also used when aspect ratios match (no cropping).
        config.mSize.data[0] = (int)viewSize.height;
        config.mSize.data[1] = (int)viewSize.height / arVideo;
    }
    
    // Calculate the viewport for the app to use when rendering
    viewport.posX = ((width - config.mSize.data[0]) / 2) + config.mPosition.data[0];
    viewport.posY = ((height - config.mSize.data[1]) / 2) + config.mPosition.data[1];
    viewport.sizeX = config.mSize.data[0];
    viewport.sizeY = config.mSize.data[1];
    
    // Set the config
    Vuforia::Renderer::getInstance().setVideoBackgroundConfig(config);
}


#pragma mark --- configuration methods ---
////////////////////////////////////////////////////////////////////////////////
// Load and Unload Data Set

- (BOOL)unloadDataSet:(Vuforia::DataSet *)theDataSet
{
    BOOL success = NO;
    
    // Get the image tracker:
    Vuforia::TrackerManager& trackerManager = Vuforia::TrackerManager::getInstance();
    Vuforia::ObjectTracker* objectTracker = static_cast<Vuforia::ObjectTracker*>(trackerManager.getTracker(Vuforia::ObjectTracker::getClassType()));
    
    if (objectTracker == NULL)
    {
        NSLog(@"Failed to unload tracking data set because the ObjectTracker has not been initialized.");
        errorCode = VUFORIA_ERRCODE_INIT_TRACKER;        
    }
    else
    {
        // If activated deactivate the data set:
        if ((theDataSet == currentDataSet) && ![self deactivateDataSet:theDataSet])
        {
            NSLog(@"Failed to deactivate data set.");
            errorCode = VUFORIA_ERRCODE_DEACTIVATE_DATASET;            
        }
        else
        {
            if (!objectTracker->destroyDataSet(theDataSet))
            {
                NSLog(@"Failed to destroy data set.");
                errorCode = VUFORIA_ERRCODE_DESTROY_DATASET;
            }
            else 
            {
                NSLog(@"Successfully unloaded data set.");
                success = YES;
            }
        }
    }
    
    currentDataSet = nil;
    
    return success;    
}

- (Vuforia::DataSet *)loadDataSet:(NSString *)dataSetPath
{
    Vuforia::DataSet *theDataSet = nil;
        
    const char* msg;
    const char* msgNotInit = "Failed to load tracking data set because the ObjectTracker has not been initialized.";
    const char* msgFailedToCreate = "Failed to create a new tracking data.";
    const char* msgFailedToLoad = "Failed to load data set.";
    
    // Get the image tracker:
    Vuforia::TrackerManager& trackerManager = Vuforia::TrackerManager::getInstance();
    Vuforia::ObjectTracker* objectTracker = static_cast<Vuforia::ObjectTracker*>(trackerManager.getTracker(Vuforia::ObjectTracker::getClassType()));
    
    if (objectTracker == NULL)
    {
        msg = msgNotInit;
        errorCode = VUFORIA_ERRCODE_INIT_TRACKER;
    }
    else
    {
        // Create the data sets:
        theDataSet = objectTracker->createDataSet();
        if (theDataSet == nil)
        {
            msg = msgFailedToCreate;
            errorCode = VUFORIA_ERRCODE_CREATE_DATASET;            
        }
        else
        {
            // Load the data set from the App Bundle
            // If the DataSet were in the Documents folder we'd use STORAGE_ABSOLUTE and the full path
            if (!theDataSet->load([dataSetPath cStringUsingEncoding:NSASCIIStringEncoding], Vuforia::STORAGE_APPRESOURCE))
            {
                msg = msgFailedToLoad;
                errorCode = VUFORIA_ERRCODE_LOAD_DATASET;            
                objectTracker->destroyDataSet(theDataSet);
                theDataSet = nil;
            }
            else
            {
                NSLog(@"Successfully loaded data set.");
            }
        }
    }
    
    if (theDataSet == nil)
    {
        NSString* nsMsg = [NSString stringWithUTF8String:msg];
        UIAlertView* alert = [[UIAlertView alloc] initWithTitle:DatasetErrorTitle message:nsMsg delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
        NSLog(@"%@", nsMsg);
        [alert show];
    }
    
    return theDataSet;
}


- (BOOL)deactivateDataSet:(Vuforia::DataSet *)theDataSet
{
    if ((currentDataSet == nil) || (theDataSet != currentDataSet))
    {
        NSLog(@"Invalid request to deactivate data set.");
        errorCode = VUFORIA_ERRCODE_DEACTIVATE_DATASET;        
        return NO;
    }
    
    BOOL success = NO;
    
    // Get the image tracker:
    Vuforia::TrackerManager& trackerManager = Vuforia::TrackerManager::getInstance();
    Vuforia::ObjectTracker* objectTracker = static_cast<Vuforia::ObjectTracker*>(trackerManager.getTracker(Vuforia::ObjectTracker::getClassType()));
    
    if (objectTracker == NULL)
    {
        NSLog(@"Failed to unload tracking data set because the ObjectTracker has not been initialized.");
        errorCode = VUFORIA_ERRCODE_INIT_TRACKER;        
    }
    else
    {
        // Activate the data set:
        if (!objectTracker->deactivateDataSet(theDataSet))
        {
            NSLog(@"Failed to deactivate data set.");
            errorCode = VUFORIA_ERRCODE_DEACTIVATE_DATASET;
        }
        else
        {
            success = YES;
        }
    }
    
    currentDataSet = nil;
    
    return success;    
}


- (BOOL)activateDataSet:(Vuforia::DataSet *)theDataSet
{
    // if we've previously recorded an activation, deactivate it
    if (currentDataSet != nil)
    {
        [self deactivateDataSet:currentDataSet];
    }
    BOOL success = NO;
    
    // Get the image tracker:
    Vuforia::TrackerManager& trackerManager = Vuforia::TrackerManager::getInstance();
    Vuforia::ObjectTracker* objectTracker = static_cast<Vuforia::ObjectTracker*>(trackerManager.getTracker(Vuforia::ObjectTracker::getClassType()));
    
    if (objectTracker == NULL) {
        NSLog(@"Failed to load tracking data set because the ObjectTracker has not been initialized.");
        errorCode = VUFORIA_ERRCODE_INIT_TRACKER;        
    } 
    else
    {
        // Activate the data set:
        if (!objectTracker->activateDataSet(theDataSet))
        {
            NSLog(@"Failed to activate data set.");
            errorCode = VUFORIA_ERRCODE_ACTIVATE_DATASET;            
        }
        else
        {
            NSLog(@"Successfully activated data set.");
            currentDataSet = theDataSet;
            success = YES;
        }
    }
    
    return success;
}



- (void) allowDataSetModification
{
    Vuforia::ObjectTracker* ot = reinterpret_cast<Vuforia::ObjectTracker*>(Vuforia::TrackerManager::getInstance().getTracker(Vuforia::ObjectTracker::getClassType()));
    
    // Deactivate the data set prior to reconfiguration:
    ot->deactivateDataSet(currentDataSet);
}


- (void) saveDataSetModifications
{
    Vuforia::ObjectTracker* it = reinterpret_cast<Vuforia::ObjectTracker*>(Vuforia::TrackerManager::getInstance().getTracker(Vuforia::ObjectTracker::getClassType()));
    
    // Deactivate the data set prior to reconfiguration:
    it->activateDataSet(currentDataSet);    
}
#pragma mark --- Data management ---
////////////////////////////////////////////////////////////////////////////////
-(NSMutableArray*) loadTextures:(NSArray*) textureList
{
    int nErr = noErr;
    NSInteger nTextures = [textureList count];
    NSMutableArray* textures = [NSMutableArray array];
    
    @try {
        for (int i = 0; i < nTextures; ++i) {
            Texture* tex = [[Texture alloc] init];
            NSString* file = [textureList objectAtIndex:i];
            
            nErr = [tex loadImage:file] == YES ? noErr : 1;
            [textures addObject:tex];
            
            if (noErr != nErr) {
                break;
            }
        }
    }
    @catch (NSException* e) {
        NSLog(@"NSMutableArray addObject exception");
    }
    
    assert([textures count] == nTextures);
    if ([textures count] != nTextures) {
        NSLog(@"All the required textures are not loaded");
    }
    
    return textures;
    
}

- (Texture *) createTexture:(NSString*)fileName
{
    Texture* tex = [[Texture alloc] init];
    [tex loadImage:fileName];
    return tex;
}

#pragma mark --- target utilities ---
////////////////////////////////////////////////////////////////////////////////
// Target Utility methods


// In the current loaded data set, find the named target

- (Vuforia::ImageTarget *) findImageTarget:(const char *) name
{
    Vuforia::TrackerManager& trackerManager = Vuforia::TrackerManager::getInstance();
    Vuforia::ObjectTracker* objectTracker = (Vuforia::ObjectTracker*)
    trackerManager.getTracker(Vuforia::ObjectTracker::getClassType());
    
    if (objectTracker != nil || currentDataSet == nil)
    {
        for(int i=0; i<currentDataSet->getNumTrackables(); i++)
        {
            if(currentDataSet->getTrackable(i)->isOfType(Vuforia::ImageTarget::getClassType()))
            {
                if(!strcmp(currentDataSet->getTrackable(i)->getName(),name))
                    return reinterpret_cast<Vuforia::ImageTarget*>(currentDataSet->getTrackable(i));
            }
        }
    }
    return NULL;
}


// See if there's a multi-target in the current data set

- (Vuforia::MultiTarget *) findMultiTarget
{
    Vuforia::TrackerManager& trackerManager = Vuforia::TrackerManager::getInstance();
    Vuforia::ObjectTracker* objectTracker = (Vuforia::ObjectTracker*)
    trackerManager.getTracker(Vuforia::ObjectTracker::getClassType());
    Vuforia::MultiTarget *mit = NULL;
    
    if (objectTracker == nil || currentDataSet == nil)
        return NULL;
    
    // Go through all Trackables to find the MultiTarget instance
    //
    for(int i=0; i<currentDataSet->getNumTrackables(); i++)
    {
        if(currentDataSet->getTrackable(i)->isOfType(Vuforia::MultiTarget::getClassType()))
        {
            NSLog(@"MultiTarget exists -> no need to create one");
            mit = reinterpret_cast<Vuforia::MultiTarget*>(currentDataSet->getTrackable(i));
            break;
        }
    }
    
    // If no MultiTarget was found, then let's create one.
    if(mit==NULL)
    {
        NSLog(@"No MultiTarget found -> creating one");
        mit = currentDataSet->createMultiTarget("FlakesBox");
        
        if(mit==NULL)
        {
            NSLog(@"ERROR: Failed to create the MultiTarget - probably the Tracker is running");
        }
    }
    
    return mit;
}


// get the Nth trackable in the data set

- (Vuforia::ImageTarget *) getImageTarget:(int)itemNo
{
    assert(currentDataSet->getNumTrackables() > 0);
    
    if (currentDataSet->getNumTrackables() > itemNo)
    {
        Vuforia::Trackable* trackable = currentDataSet->getTrackable(itemNo);
        
        assert(trackable);
        assert(trackable->getType().isOfType(Vuforia::ImageTarget::getClassType()));
        return static_cast<Vuforia::ImageTarget*>(trackable);
    }
    
    return NULL;
}

@end
