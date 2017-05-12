/*===============================================================================
Copyright (c) 2016 PTC Inc. All Rights Reserved.


Copyright (c) 2012-2015 Qualcomm Connected Experiences, Inc. All Rights Reserved.

Vuforia is a trademark of PTC Inc., registered in the United States and other 
countries.
===============================================================================*/

#import "BackgroundTextureAccessViewController.h"
#import "BackgroundTextureAccessAppDelegate.h"
#import <Vuforia/Vuforia.h>
#import <Vuforia/TrackerManager.h>
#import <Vuforia/ObjectTracker.h>
#import <Vuforia/Trackable.h>
#import <Vuforia/DataSet.h>
#import <Vuforia/CameraDevice.h>

#import "UnwindMenuSegue.h"
#import "PresentMenuSegue.h"
#import "SampleAppMenuViewController.h"

@interface BackgroundTextureAccessViewController ()

@property (weak, nonatomic) IBOutlet UIImageView *ARViewPlaceholder;

@end

@implementation BackgroundTextureAccessViewController

@synthesize tapGestureRecognizer, vapp, eaglView;


- (CGRect)getCurrentARViewFrame
{
    CGRect screenBounds = [[UIScreen mainScreen] bounds];
    CGRect viewFrame = screenBounds;
    
    // If this device has a retina display, scale the view bounds
    // for the AR (OpenGL) view
    if (YES == vapp.isRetinaDisplay) {
        viewFrame.size.width *= [UIScreen mainScreen].nativeScale;
        viewFrame.size.height *= [UIScreen mainScreen].nativeScale;
    }
    return viewFrame;
}

- (void)loadView
{
    // Custom initialization
    self.title = @"Background Texture Access";
    
    if (self.ARViewPlaceholder != nil) {
        [self.ARViewPlaceholder removeFromSuperview];
        self.ARViewPlaceholder = nil;
    }
    
    continuousAutofocusEnabled = YES;
    flashEnabled = NO;
    
    vapp = [[SampleApplicationSession alloc] initWithDelegate:self];
    
    CGRect viewFrame = [self getCurrentARViewFrame];
    
    eaglView = [[BackgroundTextureAccessEAGLView alloc] initWithFrame:viewFrame appSession:vapp];
    [self setView:eaglView];
    BackgroundTextureAccessAppDelegate *appDelegate = (BackgroundTextureAccessAppDelegate*)[[UIApplication sharedApplication] delegate];
    appDelegate.glResourceHandler = eaglView;
    
    // a single tap will trigger a single autofocus operation
    tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(autofocus:)];
    
    // double tap used to also trigger the menu
    UITapGestureRecognizer *doubleTap = [[UITapGestureRecognizer alloc] initWithTarget: self action:@selector(doubleTapGestureAction:)];
    doubleTap.numberOfTapsRequired = 2;
    [self.view addGestureRecognizer:doubleTap];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(dismissARViewController)
                                                 name:@"kDismissARViewController"
                                               object:nil];
    
    // we use the iOS notification to pause/resume the AR when the application goes (or come back from) background
    [[NSNotificationCenter defaultCenter]
     addObserver:self
     selector:@selector(pauseAR)
     name:UIApplicationWillResignActiveNotification
     object:nil];
    
    [[NSNotificationCenter defaultCenter]
     addObserver:self
     selector:@selector(resumeAR)
     name:UIApplicationDidBecomeActiveNotification
     object:nil];
    
    // initialize AR
    [vapp initAR:Vuforia::GL_20 orientation:UIInterfaceOrientationPortrait];

    // show loading animation while AR is being initialized
    [self showLoadingAnimation];
}

- (void) pauseAR {
    NSError * error = nil;
    if (![vapp pauseAR:&error]) {
        NSLog(@"Error pausing AR:%@", [error description]);
    }
}

- (void) resumeAR {
    NSError * error = nil;
    if(! [vapp resumeAR:&error]) {
        NSLog(@"Error resuming AR:%@", [error description]);
    }
    
    [eaglView updateRenderingPrimitives];
    
    // on resume, we reset the flash and the associated menu item
    Vuforia::CameraDevice::getInstance().setFlashTorchMode(false);
    flashEnabled = NO;
}


- (void)viewDidLoad
{
    [super viewDidLoad];
    [self handleARViewRotation:self.interfaceOrientation];
    
    self.showingMenu = NO;
    
    // Do any additional setup after loading the view.
    [self.navigationController setNavigationBarHidden:YES animated:NO];
    [self.view addGestureRecognizer:tapGestureRecognizer];
    
    NSLog(@"self.navigationController.navigationBarHidden: %s", self.navigationController.navigationBarHidden ? "Yes" : "No");
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    // make sure we're oriented/sized properly before reappearing/restarting
    [self handleARViewRotation:self.interfaceOrientation];
}

- (void)viewWillDisappear:(BOOL)animated
{
    // On iOS 7 viewWillDisappear may be called when the menu is shown
    // but in that case we don't want to stop the AR view
    if (self.showingMenu) {
        return;
    }
    
    [vapp stopAR:nil];
    
    // Be a good OpenGL ES citizen: now that Vuforia is paused and the render
    // thread is not executing, inform the root view controller that the
    // EAGLView should finish any OpenGL ES commands
    [self finishOpenGLESCommands];
    
    BackgroundTextureAccessAppDelegate *appDelegate = (BackgroundTextureAccessAppDelegate*)[[UIApplication sharedApplication] delegate];
    appDelegate.glResourceHandler = nil;
    
    [super viewWillDisappear:animated];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)finishOpenGLESCommands
{
    // Called in response to applicationWillResignActive.  Inform the EAGLView
    [eaglView finishOpenGLESCommands];
}


- (void)freeOpenGLESResources
{
    // Called in response to applicationDidEnterBackground.  Inform the EAGLView
    [eaglView freeOpenGLESResources];
}


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation duration:(NSTimeInterval)duration
{
    // ensure overlay size and AR orientation is correct for screen orientation
    [self handleARViewRotation:self.interfaceOrientation];
}


- (void) handleARViewRotation:(UIInterfaceOrientation)interfaceOrientation
{
    CGPoint centre, pos;
    NSInteger rot;
    
    CGRect arViewRect = [self getCurrentARViewFrame];
    
    // Set the EAGLView's position (its centre) to be the centre of the window, based on orientation
    centre.x = arViewRect.size.width / 2;
    centre.y = arViewRect.size.height / 2;
    
    if (interfaceOrientation == UIInterfaceOrientationPortrait)
    {
        NSLog(@"ARVC: Rotating to Portrait");
        pos.x = centre.y;
        pos.y = centre.x;
        rot = 0;
    }
    else if (interfaceOrientation == UIInterfaceOrientationPortraitUpsideDown)
    {
        NSLog(@"ARVC: Rotating to Upside Down");
        pos.x = centre.y;
        pos.y = centre.x;
        rot = 180;
    }
    else if (interfaceOrientation == UIInterfaceOrientationLandscapeLeft)
    {
        NSLog(@"ARVC: Rotating to Landscape Left");
        pos = centre;
        rot = 90;
    }
    else if (interfaceOrientation == UIInterfaceOrientationLandscapeRight)
    {
        NSLog(@"ARVC: Rotating to Landscape Right");
        pos = centre;
        rot = 270;
    } else {
        pos.x = centre.y;
        pos.y = centre.x;
        rot = 0;
    }
    
    CGAffineTransform rotate = CGAffineTransformMakeRotation(rot * M_PI  / 180);
    [eaglView setOrientationTransform:rotate withLayerPosition:pos];
}


#pragma mark - loading animation

- (void) showLoadingAnimation {
    CGRect indicatorBounds;
    CGRect mainBounds = [[UIScreen mainScreen] bounds];
    int smallerBoundsSize = MIN(mainBounds.size.width, mainBounds.size.height);
    int largerBoundsSize = MAX(mainBounds.size.width, mainBounds.size.height);
    indicatorBounds = CGRectMake(largerBoundsSize / 2 - 12,
                                     smallerBoundsSize / 2 - 12, 24, 24);
    

    UIActivityIndicatorView *loadingIndicator = [[UIActivityIndicatorView alloc]
                                                  initWithFrame:indicatorBounds];
    
    loadingIndicator.tag  = 1;
    loadingIndicator.activityIndicatorViewStyle = UIActivityIndicatorViewStyleWhiteLarge;
    
    [eaglView addSubview:loadingIndicator];
    [loadingIndicator startAnimating];
}

- (void) hideLoadingAnimation {
    UIActivityIndicatorView *loadingIndicator = (UIActivityIndicatorView *)[eaglView viewWithTag:1];
    [loadingIndicator removeFromSuperview];
}


#pragma mark - SampleApplicationControl

// Initialize the application trackers
- (bool) doInitTrackers {
    // Initialize the image tracker
    Vuforia::TrackerManager& trackerManager = Vuforia::TrackerManager::getInstance();
    Vuforia::Tracker* trackerBase = trackerManager.initTracker(Vuforia::ObjectTracker::getClassType());
    if (trackerBase == NULL)
    {
        NSLog(@"Failed to initialize ObjectTracker.");
        return false;
    }
    return true;
}

// load the data associated to the trackers
- (bool) doLoadTrackersData {
    return [self loadAndActivateImageTrackerDataSet:@"Tarmac.xml"];;
}

// start the application trackers
- (bool) doStartTrackers {
    Vuforia::TrackerManager& trackerManager = Vuforia::TrackerManager::getInstance();
    Vuforia::Tracker* tracker = trackerManager.getTracker(Vuforia::ObjectTracker::getClassType());
    if(tracker == 0) {
        return false;
    }
    tracker->start();
    return true;
}

// callback called when the initailization of the AR is done
- (void) onInitARDone:(NSError *)initError {
    UIActivityIndicatorView *loadingIndicator = (UIActivityIndicatorView *)[eaglView viewWithTag:1];
    [loadingIndicator removeFromSuperview];
    
    if (initError == nil) {
        NSError * error = nil;
        [vapp startAR:Vuforia::CameraDevice::CAMERA_DIRECTION_BACK error:&error];
        
        //notify the opengl view that the camera is started
        [eaglView cameraDidStart];
        
        [eaglView updateRenderingPrimitives];
        
        // by default, we try to set the continuous auto focus mode
        continuousAutofocusEnabled = Vuforia::CameraDevice::getInstance().setFocusMode(Vuforia::CameraDevice::FOCUS_MODE_CONTINUOUSAUTO);
        
    } else {
        NSLog(@"Error initializing AR:%@", [initError description]);
        dispatch_async( dispatch_get_main_queue(), ^{
            
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error"
                                                            message:[initError localizedDescription]
                                                           delegate:self
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];
            [alert show];
        });
    }
}

#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    [[NSNotificationCenter defaultCenter] postNotificationName:@"kDismissARViewController" object:nil];
}

- (void)dismissARViewController
{
    [self.navigationController setNavigationBarHidden:NO animated:YES];
    [self.navigationController popToRootViewControllerAnimated:NO];
}

- (void)configureVideoBackgroundWithViewWidth:(float)viewWidth andHeight:(float)viewHeight
{
    [eaglView configureVideoBackgroundWithViewWidth:(float)viewWidth andHeight:(float)viewHeight];
}

// update from the Vuforia loop
- (void) onVuforiaUpdate: (Vuforia::State *) state
{
}

// stop your trackerts
- (bool) doStopTrackers {
    Vuforia::TrackerManager& trackerManager = Vuforia::TrackerManager::getInstance();
    Vuforia::Tracker* tracker = trackerManager.getTracker(Vuforia::ObjectTracker::getClassType());
    
    if (NULL == tracker) {
        NSLog(@"ERROR: failed to get the tracker from the tracker manager");
        return false;
    }
    
    tracker->stop();
    return true;
}

// unload the data associated to your trackers
- (bool) doUnloadTrackersData {
    if (dataSet != NULL) {
        // Get the image tracker:
        Vuforia::TrackerManager& trackerManager = Vuforia::TrackerManager::getInstance();
        Vuforia::ObjectTracker* objectTracker = static_cast<Vuforia::ObjectTracker*>(trackerManager.getTracker(Vuforia::ObjectTracker::getClassType()));
        
        if (objectTracker == NULL)
        {
            NSLog(@"Failed to unload tracking data set because the ImageTracker has not been initialized.");
            return false;
        }
        // Activate the data set:
        if (!objectTracker->deactivateDataSet(dataSet))
        {
            NSLog(@"Failed to deactivate data set.");
            return false;
        }
        // Activate the data set:
        if (!objectTracker->destroyDataSet(dataSet))
        {
            NSLog(@"Failed to destroy data set.");
            return false;
        }
        dataSet = NULL;
    }
    return true;
}

// deinitialize your trackers
- (bool) doDeinitTrackers {
    Vuforia::TrackerManager& trackerManager = Vuforia::TrackerManager::getInstance();
    trackerManager.deinitTracker(Vuforia::ObjectTracker::getClassType());
    return true;
}

- (void)autofocus:(UITapGestureRecognizer *)sender
{
    [self performSelector:@selector(cameraPerformAutoFocus) withObject:nil afterDelay:.4];
}

- (void)cameraPerformAutoFocus
{
    Vuforia::CameraDevice::getInstance().setFocusMode(Vuforia::CameraDevice::FOCUS_MODE_TRIGGERAUTO);
    
    // After triggering an autofocus event,
    // we must restore the previous focus mode
    if (continuousAutofocusEnabled)
    {
        [self performSelector:@selector(restoreContinuousAutoFocus) withObject:nil afterDelay:2.0];
    }
}

- (void)restoreContinuousAutoFocus
{
    Vuforia::CameraDevice::getInstance().setFocusMode(Vuforia::CameraDevice::FOCUS_MODE_CONTINUOUSAUTO);
}

- (void)doubleTapGestureAction:(UITapGestureRecognizer*)theGesture
{
    if (!self.showingMenu) {
        [self performSegueWithIdentifier: @"PresentMenu" sender: self];
    }
}


// Load the image tracker data set
- (BOOL)loadAndActivateImageTrackerDataSet:(NSString*)dataFile
{
    NSLog(@"loadAndActivateImageTrackerDataSet (%@)", dataFile);
    BOOL ret = YES;
    dataSet = NULL;
    
    // Get the Vuforia tracker manager image tracker
    Vuforia::TrackerManager& trackerManager = Vuforia::TrackerManager::getInstance();
    Vuforia::ObjectTracker* objectTracker = static_cast<Vuforia::ObjectTracker*>(trackerManager.getTracker(Vuforia::ObjectTracker::getClassType()));
    
    if (NULL == objectTracker) {
        NSLog(@"ERROR: failed to get the ImageTracker from the tracker manager");
        ret = NO;
    } else {
        dataSet = objectTracker->createDataSet();
        
        if (NULL != dataSet) {
            // Load the data set from the app's resources location
            if (!dataSet->load([dataFile cStringUsingEncoding:NSASCIIStringEncoding], Vuforia::STORAGE_APPRESOURCE)) {
                NSLog(@"ERROR: failed to load data set");
                objectTracker->destroyDataSet(dataSet);
                dataSet = NULL;
                ret = NO;
            } else {
                // Activate the data set
                if (objectTracker->activateDataSet(dataSet)) {
                    NSLog(@"INFO: successfully activated data set");
                }
                else {
                    NSLog(@"ERROR: failed to activate data set");
                    ret = NO;
                }
            }
        }
        else {
            NSLog(@"ERROR: failed to create data set");
            ret = NO;
        }
        
    }
    
    return ret;
}


#pragma mark - menu delegate protocol implementation

- (BOOL) menuProcess:(NSString *)itemName value:(BOOL)value
{
    // no menu options for this feature
    return false;
}

- (void) menuDidExit
{
    self.showingMenu = NO;
}


#pragma mark - Navigation

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue isKindOfClass:[PresentMenuSegue class]]) {
        UIViewController *dest = [segue destinationViewController];
        if ([dest isKindOfClass:[SampleAppMenuViewController class]]) {
            self.showingMenu = YES;
            
            SampleAppMenuViewController *menuVC = (SampleAppMenuViewController *)dest;
            menuVC.menuDelegate = self;
            menuVC.sampleAppFeatureName = @"Background Texture";
            menuVC.backSegueId = @"BackToBackgroundTexture";
            menuVC.dismissItemName = @"About";
            
        }
    }
}

@end
