/*===============================================================================
Copyright (c) 2016 PTC Inc. All Rights Reserved.


Copyright (c) 2012-2015 Qualcomm Connected Experiences, Inc. All Rights Reserved.

Vuforia is a trademark of PTC Inc., registered in the United States and other 
countries.
===============================================================================*/

#import "BooksAppDelegate.h"
#import "BooksViewController.h"
#import "BooksManager.h"
#import "BookWebDetailViewController.h"
#import "TargetOverlayView.h"

#import <Vuforia/Vuforia.h>
#import <Vuforia/TrackerManager.h>
#import <Vuforia/ObjectTracker.h>
#import <Vuforia/ImageTarget.h>
#import <Vuforia/DataSet.h>
#import <Vuforia/CameraDevice.h>
#import <Vuforia/TargetFinder.h>
#import <Vuforia/TargetSearchResult.h>


// ----------------------------------------------------------------------------
// Credentials for authenticating with the Books service
// These are read-only access keys for accessing the image database
// specific to this sample application - the keys should be replaced
// by your own access keys. You should be very careful how you share
// your credentials, especially with untrusted third parties, and should
// take the appropriate steps to protect them within your application code
// ----------------------------------------------------------------------------
static const char* const kAccessKey = "669ab267d2332a9c8f8c05730f2abd00a8c34fbd";
static const char* const kSecretKey = "7afac700a02bd5d68ab2b0b4dcaca982dda5a17e";


@interface BooksViewController ()

@property (weak, nonatomic) IBOutlet UIImageView *ARViewPlaceholder;
@property (nonatomic) BOOL isShowingWebDetail;
@property (nonatomic) BOOL pausedWhileShowingBookWebDetail;
@property (nonatomic) BOOL scanningMode;
@property (nonatomic) BOOL isVisualSearchOn;

@end

@implementation BooksViewController

@synthesize tapGestureRecognizer, vapp, eaglView, bookOverlayController;
@synthesize lastScannedBook, lastTargetIDScanned;
@synthesize isShowingWebDetail, pausedWhileShowingBookWebDetail, scanningMode, isVisualSearchOn;

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    if (lastTargetIDScanned != nil) {
        lastTargetIDScanned = nil;
    }
    if (lastScannedBook != nil) {
        lastScannedBook = nil;
    }
    
    if (bookOverlayController) {
        [bookOverlayController killTimer];
        bookOverlayController = nil;
    }
}

- (NSString *) lastTargetIDScanned {
    return lastTargetIDScanned;
}

- (void) setLastTargetIDScanned:(NSString *) targetId {
    if (lastTargetIDScanned != nil) {
        lastTargetIDScanned = nil;
    }
    if (targetId != nil) {
        lastTargetIDScanned = [NSString stringWithString:targetId];
    }
}


- (void) setLastScannedBook: (Book *) book {
    if (lastScannedBook != nil) {
        lastScannedBook = nil;
    }
    if (book != nil) {
        lastScannedBook = book;
    }
}


- (BOOL) isVisualSearchOn {
    return isVisualSearchOn;
}

- (void) setVisualSearchOn:(BOOL) isOn {
    isVisualSearchOn = isOn;
    
    if (isOn) {
        [self scanlineStart];
    } else {
        [self scanlineStop];
    }
}


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
    self.title = @"Books";
    
    if (self.ARViewPlaceholder != nil) {
        [self.ARViewPlaceholder removeFromSuperview];
        self.ARViewPlaceholder = nil;
    }
    
    pausedWhileShowingBookWebDetail = NO;
    isShowingWebDetail = NO;
    scanningMode = YES;
    isVisualSearchOn = NO;
    lastScannedBook = nil;
    lastTargetIDScanned = nil;
    
    vapp = [[SampleApplicationSession alloc] initWithDelegate:self];
    
    CGRect viewFrame = [self getCurrentARViewFrame];
    
    bookOverlayController = [[BooksOverlayViewController alloc] initWithDelegate:self];
    
    eaglView = [[BooksEAGLView alloc] initWithFrame:viewFrame delegate:self appSession:vapp];
    [eaglView addSubview:bookOverlayController.view];
    [self setView:eaglView];
    BooksAppDelegate *appDelegate = (BooksAppDelegate*)[[UIApplication sharedApplication] delegate];
    appDelegate.glResourceHandler = eaglView;
    
    // a single tap will trigger a single autofocus operation
    tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
    tapGestureRecognizer.delegate = self;
    
    [self scanlineCreate];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(dismissARViewController)
                                                 name:@"kDismissARViewController"
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(bookWebDetailDismissed:) name:@"kBookWebDetailDismissed" object:nil];
    
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
    [vapp initAR:Vuforia::GL_20 orientation:self.interfaceOrientation];

    // show loading animation while AR is being initialized
    [self showLoadingAnimation];
}

- (void) pauseAR
{
    if (isShowingWebDetail)
    {
        pausedWhileShowingBookWebDetail = YES;
        if (self.bookWebDetailController != nil)
        {
            [self.bookWebDetailController.navigationController popViewControllerAnimated:NO];
        }
    }
    
    NSError * error = nil;
    if (![vapp pauseAR:&error]) {
        NSLog(@"Error pausing AR:%@", [error description]);
    }
}

- (void) resumeAR
{
    NSError * error = nil;
    if(! [vapp resumeAR:&error]) {
        NSLog(@"Error resuming AR:%@", [error description]);
    }

    [eaglView updateRenderingPrimitives];

    // on resume, we reset the flash
    Vuforia::CameraDevice::getInstance().setFlashTorchMode(false);
        
    [self handleRotation:self.interfaceOrientation];
    
    if (pausedWhileShowingBookWebDetail)
    {
        //  Show Book WebView Detail
        isShowingWebDetail = YES;
        pausedWhileShowingBookWebDetail = NO;
        [self performSegueWithIdentifier:@"PushWebDetail" sender:self];
    }
}

-(void)showUIAlertFromErrorCode:(int)code
{
    if (lastErrorCode == code)
    {
        // we don't want to show twice the same error
        return;
    }
    lastErrorCode = code;
    
    NSString *title = nil;
    NSString *message = nil;
    
    if (code == Vuforia::TargetFinder::UPDATE_ERROR_NO_NETWORK_CONNECTION)
    {
        title = @"Network Unavailable";
        message = @"Please check your internet connection and try again.";
    }
    else if (code == Vuforia::TargetFinder::UPDATE_ERROR_REQUEST_TIMEOUT)
    {
        title = @"Request Timeout";
        message = @"The network request has timed out, please check your internet connection and try again.";
    }
    else if (code == Vuforia::TargetFinder::UPDATE_ERROR_SERVICE_NOT_AVAILABLE)
    {
        title = @"Service Unavailable";
        message = @"The cloud recognition service is unavailable, please try again later.";
    }
    else if (code == Vuforia::TargetFinder::UPDATE_ERROR_UPDATE_SDK)
    {
        title = @"Unsupported Version";
        message = @"The application is using an unsupported version of Vuforia.";
    }
    else if (code == Vuforia::TargetFinder::UPDATE_ERROR_TIMESTAMP_OUT_OF_RANGE)
    {
        title = @"Clock Sync Error";
        message = @"Please update the date and time and try again.";
    }
    else if (code == Vuforia::TargetFinder::UPDATE_ERROR_AUTHORIZATION_FAILED)
    {
        title = @"Authorization Error";
        message = @"The cloud recognition service access keys are incorrect or have expired.";
    }
    else if (code == Vuforia::TargetFinder::UPDATE_ERROR_PROJECT_SUSPENDED)
    {
        title = @"Authorization Error";
        message = @"The cloud recognition service has been suspended.";
    }
    else if (code == Vuforia::TargetFinder::UPDATE_ERROR_BAD_FRAME_QUALITY)
    {
        title = @"Poor Camera Image";
        message = @"The camera does not have enough detail, please try again later";
    }
    else
    {
        title = @"Unknown error";
        message = [NSString stringWithFormat:@"An unknown error has occurred (Code %d)", code];
    }
    
    //  Call the UIAlert on the main thread to avoid undesired behaviors
    dispatch_async( dispatch_get_main_queue(), ^{
        if (title && message)
        {
            UIAlertView *anAlertView = [[UIAlertView alloc] initWithTitle:title
                                                                  message:message
                                                                 delegate:self
                                                        cancelButtonTitle:@"OK"
                                                        otherButtonTitles:nil];
            anAlertView.tag = 42;
            [anAlertView show];
        }
    });
}

- (void)bookWebDetailDismissed:(NSNotification *)notification
{
    isShowingWebDetail = NO;
    [self handleRotation:self.interfaceOrientation];
}


- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // we set the UINavigationControllerDelegate
    // so that we can enforce portrait only for this view controller
    self.navigationController.delegate = (id<UINavigationControllerDelegate>)self;
    
    // Do any additional setup after loading the view.
    [self.navigationController setNavigationBarHidden:YES animated:NO];
    [self.view addGestureRecognizer:tapGestureRecognizer];
    
    NSLog(@"self.navigationController.navigationBarHidden: %s", self.navigationController.navigationBarHidden ? "Yes" : "No");
    
    lastErrorCode = 99;
}

- (void)viewWillDisappear:(BOOL)animated
{
    if (!isShowingWebDetail) 
    {    
        // so we check the boolean to avoid shutting down AR
        [vapp stopAR:nil];
        
        // Be a good OpenGL ES citizen: now that Vuforia is paused and the render
        // thread is not executing, inform the root view controller that the
        // EAGLView should finish any OpenGL ES commands
        [self finishOpenGLESCommands];
        
        BooksAppDelegate *appDelegate = (BooksAppDelegate*)[[UIApplication sharedApplication] delegate];
        appDelegate.glResourceHandler = nil;
    }
    
    [super viewWillDisappear:animated];
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

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    if (!self.pausedWhileShowingBookWebDetail)
    {
        isShowingWebDetail = NO;
    }
    
    [self.navigationController setNavigationBarHidden:YES animated:NO];
    
    // make sure we're oriented/sized properly before reappearing/restarting
    [self handleARViewRotation:self.interfaceOrientation];
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation duration:(NSTimeInterval)duration
{
    [self handleRotation:interfaceOrientation];
}

- (void) handleRotation:(UIInterfaceOrientation)interfaceOrientation
{
    // ensure overlay size and AR orientation is correct for screen orientation
    [self handleARViewRotation:self.interfaceOrientation];
    [bookOverlayController handleViewRotation:self.interfaceOrientation];
    [vapp changeOrientation:self.interfaceOrientation];
    [eaglView updateRenderingPrimitives];
    
}

- (void) handleARViewRotation:(UIInterfaceOrientation)interfaceOrientation
{
    // Retrieve up-to-date view frame.
    // Note that, while on iOS 7 and below, the frame size does not change
    // with rotation events,
    // on the contray, on iOS 8 the frame size is orientation-dependent,
    // i.e. width and height get swapped when switching from
    // landscape to portrait and vice versa.
    // This requires that the latest (current) view frame is retrieved.
    CGRect viewBounds = [[UIScreen mainScreen] bounds];
    
    int smallerSize = MIN(viewBounds.size.width, viewBounds.size.height);
    int largerSize = MAX(viewBounds.size.width, viewBounds.size.height);
    
    if (interfaceOrientation == UIInterfaceOrientationPortrait ||
        interfaceOrientation == UIInterfaceOrientationPortraitUpsideDown)
    {
        NSLog(@"AR View: Rotating to Portrait");
        
        CGRect viewBounds;
        viewBounds.origin.x = 0;
        viewBounds.origin.y = 0;
        viewBounds.size.width = smallerSize;
        viewBounds.size.height = largerSize;
        
        [eaglView setFrame:viewBounds];
    }
    else if (interfaceOrientation == UIInterfaceOrientationLandscapeLeft ||
             interfaceOrientation == UIInterfaceOrientationLandscapeRight)
    {
        NSLog(@"AR View: Rotating to Landscape");
        
        CGRect viewBounds;
        viewBounds.origin.x = 0;
        viewBounds.origin.y = 0;
        viewBounds.size.width = largerSize;
        viewBounds.size.height = smallerSize;
        
        [eaglView setFrame:viewBounds];
    }
    
    if (isVisualSearchOn) {
        [self scanlineUpdateRotation];
    }
}

#pragma mark - loading animation

- (void) showLoadingAnimation {
    CGRect indicatorBounds;
    CGRect mainBounds = [[UIScreen mainScreen] bounds];
    int smallerBoundsSize = MIN(mainBounds.size.width, mainBounds.size.height);
    int largerBoundsSize = MAX(mainBounds.size.width, mainBounds.size.height);
    UIInterfaceOrientation orientation = [[UIApplication sharedApplication] statusBarOrientation];
    if (orientation == UIInterfaceOrientationPortrait || orientation == UIInterfaceOrientationPortraitUpsideDown ) {
        indicatorBounds = CGRectMake(smallerBoundsSize / 2 - 12,
                                     largerBoundsSize / 2 - 12, 24, 24);
    }
    else {
        indicatorBounds = CGRectMake(largerBoundsSize / 2 - 12,
                                     smallerBoundsSize / 2 - 12, 24, 24);
    }
    
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
    Vuforia::TrackerManager& trackerManager = Vuforia::TrackerManager::getInstance();
    Vuforia::Tracker* trackerBase = trackerManager.initTracker(Vuforia::ObjectTracker::getClassType());
    // Set the visual search credentials:
    Vuforia::TargetFinder* targetFinder = static_cast<Vuforia::ObjectTracker*>(trackerBase)->getTargetFinder();
    if (targetFinder == NULL)
    {
        NSLog(@"Failed to get target finder.");
        return false;
    }
    
    return true;
}

// load the data associated to the trackers
- (bool) doLoadTrackersData {
    Vuforia::TrackerManager& trackerManager = Vuforia::TrackerManager::getInstance();
    Vuforia::ObjectTracker* objectTracker = static_cast<Vuforia::ObjectTracker*>(trackerManager.getTracker(Vuforia::ObjectTracker::getClassType()));
    if (objectTracker == NULL)
    {
        NSLog(@"Failed to load tracking data set because the ObjectTracker has not been initialized.");
        return false;
    }
    
    // Initialize visual search:
    Vuforia::TargetFinder* targetFinder = objectTracker->getTargetFinder();
    if (targetFinder == NULL)
    {
        NSLog(@"Failed to get target finder.");
        return false;
    }
    
    NSDate *start = [NSDate date];
    
    // Start initialization:
    if (targetFinder->startInit(kAccessKey, kSecretKey))
    {
        targetFinder->waitUntilInitFinished();
        
        NSDate *methodFinish = [NSDate date];
        NSTimeInterval executionTime = [methodFinish timeIntervalSinceDate:start];
        
        NSLog(@"waitUntilInitFinished Execution Time: %lf", executionTime);
    }
    
    int resultCode = targetFinder->getInitState();
    if ( resultCode != Vuforia::TargetFinder::INIT_SUCCESS)
    {
        int initErrorCode;
        if(resultCode == Vuforia::TargetFinder::INIT_ERROR_NO_NETWORK_CONNECTION)
        {
            initErrorCode = Vuforia::TargetFinder::UPDATE_ERROR_NO_NETWORK_CONNECTION;
        }
        else
        {
            initErrorCode = Vuforia::TargetFinder::UPDATE_ERROR_SERVICE_NOT_AVAILABLE;
        }
        [self showUIAlertFromErrorCode: initErrorCode];
        return false;
    } else {
        NSLog(@"target finder initialized");
    }
    return true;
}

// start the application trackers
- (bool) doStartTrackers {
    Vuforia::TrackerManager& trackerManager = Vuforia::TrackerManager::getInstance();
    
    Vuforia::ObjectTracker* objectTracker = static_cast<Vuforia::ObjectTracker*>(trackerManager.getTracker(Vuforia::ObjectTracker::getClassType()));
    if (objectTracker == 0) {
        NSLog(@"ObjectTracker null.");
        return false;
    }
    objectTracker->start();
    
    // Start cloud based recognition if we are in scanning mode:
    if (scanningMode)
    {
        Vuforia::TargetFinder* targetFinder = objectTracker->getTargetFinder();
        [self scanlineStart];
        isVisualSearchOn = targetFinder->startRecognition();
    }
    return true;
}

// callback called when the initailization of the AR is done
- (void) onInitARDone:(NSError *)initError {
    UIActivityIndicatorView *loadingIndicator = (UIActivityIndicatorView *)[eaglView viewWithTag:1];
    [loadingIndicator removeFromSuperview];
    
    if (initError == nil) {
        NSError * error = nil;
        [vapp startAR:Vuforia::CameraDevice::CAMERA_DIRECTION_BACK error:&error];
        
        // by default, we try to set the continuous auto focus mode
        Vuforia::CameraDevice::getInstance().setFocusMode(Vuforia::CameraDevice::FOCUS_MODE_CONTINUOUSAUTO);
        
        //  the camera is initialized, this call will reset the screen configuration
        [self handleRotation:self.interfaceOrientation];
        
        [eaglView updateRenderingPrimitives];
        
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
- (void) onVuforiaUpdate: (Vuforia::State *) state {
    // Get the tracker manager:
    Vuforia::TrackerManager& trackerManager = Vuforia::TrackerManager::getInstance();
    
    // Get the image tracker:
    Vuforia::ObjectTracker* objectTracker = static_cast<Vuforia::ObjectTracker*>(trackerManager.getTracker(Vuforia::ObjectTracker::getClassType()));
    
    // Get the target finder:
    Vuforia::TargetFinder* finder = objectTracker->getTargetFinder();
    
    // Check if there are new results available:
    const int statusCode = finder->updateSearchResults();
    if (statusCode < 0)
    {
        // Show a message if we encountered an error:
        NSLog(@"update search result failed:%d", statusCode);
        if (statusCode == Vuforia::TargetFinder::UPDATE_ERROR_NO_NETWORK_CONNECTION) {
            [self showUIAlertFromErrorCode:statusCode];
        }
    }
    else if (statusCode == Vuforia::TargetFinder::UPDATE_RESULTS_AVAILABLE)
    {
        
        // Iterate through the new results:
        for (int i = 0; i < finder->getResultCount(); ++i)
        {
            const Vuforia::TargetSearchResult* result = finder->getResult(i);
            
            // Check if this target is suitable for tracking:
            if (result->getTrackingRating() > 0)
            {
                // Create a new Trackable from the result:
                Vuforia::Trackable* newTrackable = finder->enableTracking(*result);
                if (newTrackable != 0)
                {
                    Vuforia::ImageTarget* imageTargetTrackable = (Vuforia::ImageTarget*)newTrackable;
                    
                    //  Avoid entering on ContentMode when a bad target is found
                    //  (Bad Targets are targets that are exists on the Books database but not on our
                    //  own book database)
                    if (![[BooksManager sharedInstance] isBadTarget:imageTargetTrackable->getUniqueTargetId()])
                    {
                        NSLog(@"Successfully created new trackable '%s' with rating '%d'.",
                              newTrackable->getName(), result->getTrackingRating());
                    }
                }
                else
                {
                    NSLog(@"Failed to create new trackable.");
                }
            }
        }
    }
    
}


// stop your trackerts
- (bool) doStopTrackers {
    Vuforia::TrackerManager& trackerManager = Vuforia::TrackerManager::getInstance();
    Vuforia::ObjectTracker* objectTracker = static_cast<Vuforia::ObjectTracker*>(trackerManager.getTracker(Vuforia::ObjectTracker::getClassType()));
    
    if (objectTracker == NULL) {
        NSLog(@"Failed to unload tracking data set because the ObjectTracker has not been initialized.");
        return false;
    }
    objectTracker->stop();
        
    // Stop cloud based recognition:
    Vuforia::TargetFinder* targetFinder = objectTracker->getTargetFinder();
    if (targetFinder != NULL) {
        isVisualSearchOn = !targetFinder->stop();
    }
    return true;
}

// unload the data associated to your trackers
- (bool) doUnloadTrackersData {
    Vuforia::TrackerManager& trackerManager = Vuforia::TrackerManager::getInstance();
    Vuforia::ObjectTracker* objectTracker = static_cast<Vuforia::ObjectTracker*>(trackerManager.getTracker(Vuforia::ObjectTracker::getClassType()));
    
    if (objectTracker == NULL) {
        NSLog(@"Failed to unload tracking data set because the ObjectTracker has not been initialized.");
        return false;
    }
    
    // Deinitialize visual search:
    Vuforia::TargetFinder* finder = objectTracker->getTargetFinder();
    finder->deinit();
    return true;
}

// deinitialize your trackers
- (bool) doDeinitTrackers {
    return true;
}

// tap handler
- (void)handleTap:(UITapGestureRecognizer *)sender {
    if (sender.state == UIGestureRecognizerStateEnded) {
        // handling code
        CGPoint touchPoint = [sender locationInView:eaglView];
        if ([eaglView isTouchOnTarget:touchPoint] ) {
            if (lastScannedBook)
            {
                //  Show Book WebView Detail
                isShowingWebDetail = YES;
                [self performSegueWithIdentifier:@"PushWebDetail" sender:self];
            }
        }
    }
    [self performSelector:@selector(cameraPerformAutoFocus) withObject:nil afterDelay:.4];
}

- (void)cameraPerformAutoFocus
{
    Vuforia::CameraDevice::getInstance().setFocusMode(Vuforia::CameraDevice::FOCUS_MODE_TRIGGERAUTO);
    
    // After triggering an autofocus event,
    // we try and restore the continuous autofocus mode
    [self performSelector:@selector(restoreContinuousAutoFocus) withObject:nil afterDelay:2.0];
}

- (void)restoreContinuousAutoFocus
{
    Vuforia::CameraDevice::getInstance().setFocusMode(Vuforia::CameraDevice::FOCUS_MODE_CONTINUOUSAUTO);
}

- (void) toggleVisualSearch:(BOOL)visualSearchOn
{
    Vuforia::TrackerManager& trackerManager = Vuforia::TrackerManager::getInstance();
    Vuforia::ObjectTracker* objectTracker = static_cast<Vuforia::ObjectTracker*>(trackerManager.getTracker(Vuforia::ObjectTracker::getClassType()));
    Vuforia::TargetFinder* targetFinder = objectTracker->getTargetFinder();
    if (visualSearchOn == NO)
    {
        targetFinder->startRecognition();
        isVisualSearchOn = YES;
    }
    else
    {
        targetFinder->stop();
        isVisualSearchOn = NO;
    }
}


- (void)setOverlayLayer:(CALayer *)overlayLayer
{
    [eaglView setOverlayLayer:overlayLayer];
}

- (void)enterScanningMode
{
    [eaglView enterScanningMode];
}


#pragma mark - Navigation

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // prepare segue for BookWebDetailViewController
    UIViewController *dest = segue.destinationViewController;
    if ([dest isKindOfClass:[BookWebDetailViewController class]]) {
        [self.navigationController setNavigationBarHidden:NO animated:NO];
        
        BookWebDetailViewController *bookWebDetailViewController = (BookWebDetailViewController*)dest;
        self.bookWebDetailController = bookWebDetailViewController;
        bookWebDetailViewController.book = lastScannedBook;
    }
}

#pragma mark - scan line
const int VIEW_SCAN_LINE_TAG = 1111;

- (void) scanlineCreate {
    CGRect frame = [[UIScreen mainScreen] bounds];
    
    UIImageView *scanLineView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, frame.size.width, 50)];
    scanLineView.tag = VIEW_SCAN_LINE_TAG;
    scanLineView.contentMode = UIViewContentModeScaleToFill;
    [scanLineView setImage:[UIImage imageNamed:@"scanline.png"]];
    [scanLineView setHidden:YES];
    [self.view addSubview:scanLineView];
}

- (void) scanlineStart {
    UIView * scanLineView = [self.view viewWithTag:VIEW_SCAN_LINE_TAG];
    if (scanLineView) {
        [scanLineView setHidden:NO];
        CGRect frame = [[UIScreen mainScreen] bounds];
        scanLineView.frame = CGRectMake(0, 0, frame.size.width, 50);

        NSLog(@"frame: %@", NSStringFromCGRect(frame));
        CABasicAnimation *animation = [CABasicAnimation
                                       animationWithKeyPath:@"position"];
        
        animation.toValue = [NSValue valueWithCGPoint:CGPointMake(scanLineView.center.x, frame.size.height)];
        animation.autoreverses = YES;
        // we make the animation faster in landcsape mode
        animation.duration = frame.size.height > frame.size.width ? 4.0 : 2.0;
        animation.repeatCount = HUGE_VAL;
        animation.removedOnCompletion = NO;
        animation.fillMode = kCAFillModeForwards;
        [scanLineView.layer addAnimation:animation forKey:@"position"];
    }
}

- (void) scanlineStop {
    UIView * scanLineView = [self.view viewWithTag:VIEW_SCAN_LINE_TAG];
    if (scanLineView) {
        [scanLineView setHidden:YES];
        [scanLineView.layer removeAllAnimations];
    }
}

- (void) scanlineUpdateRotation {
    [self scanlineStop];
    [self scanlineStart];
}


@end
