/*===============================================================================
Copyright (c) 2012-2014 Qualcomm Connected Experiences, Inc. All Rights Reserved.

Vuforia is a trademark of PTC Inc., registered in the United States and other 
countries.
===============================================================================*/


#import <UIKit/UIKit.h>

@class ARViewController, OverlayViewController;

@interface ARParentViewController : UIViewController

@property (nonatomic, strong) OverlayViewController* overlayViewController; // for the overlay view
@property (nonatomic, strong) ARViewController* arViewController; // for the Augmented Reality view
@property (nonatomic, strong) UIImageView* parentView; // a container view
@property (nonatomic, strong) UIImageView* splashView;
@property (nonatomic, strong) UIWindow* appWindow;

@property (nonatomic) CGRect arViewRect;

- (id)initWithWindow:(UIWindow*)window;
- (void)createParentViewAndSplashContinuation;
- (void)endSplash:(NSTimer*)theTimer;
- (void)updateSplashScreenImageForLandscape;
- (BOOL)isRetinaEnabled;
- (void)freeOpenGLESResources;

@end
