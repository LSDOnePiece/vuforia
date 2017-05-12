/*===============================================================================
Copyright (c) 2016 PTC Inc. All Rights Reserved.

Copyright (c) 2012-2014 Qualcomm Connected Experiences, Inc. All Rights Reserved.

Vuforia is a trademark of PTC Inc., registered in the United States and other 
countries.
===============================================================================*/

#import "DomParentViewController.h"
#import "Dominoes.h"
#import "ButtonOverlayViewController.h"
#import "DomOverlayViewController.h"
#import "ARViewController.h"
#import "EAGLView.h"
#import "Vuforiautils.h"
#import <QuartzCore/QuartzCore.h>

extern bool isInterfaceOrientationPortrait;

@implementation DomParentViewController // subclass of ARParentViewController

@synthesize buttonOverlayVC;

// Implement loadView to create a view hierarchy programmatically, without using a nib.
- (void)loadView
{
    [self createParentViewAndSplashContinuation];
    
    // Add the EAGLView and the overlay view to the window
    self.arViewController = [[ARViewController alloc] init];
    
    // need to set size here to setup camera image size for AR
    self.arViewController.arViewSize = self.arViewRect.size;
    [self.parentView addSubview:self.arViewController.view];
    
    // Create an auto-rotating overlay view and its view controller (used for
    // displaying buttons)
    buttonOverlayVC = [[ButtonOverlayViewController alloc] init];
    dominoesSetButtonOverlay(buttonOverlayVC);
    [buttonOverlayVC setMenuCallBack:@selector(showMenu) forTarget:self];
    [self.parentView addSubview: buttonOverlayVC.view];
    
    // Hide the AR and button overlay views so the parent view can be seen
    // during start-up (the parent view contains the splash continuation image
    // on iPad and is empty on iPhone and iPod)
    [self.arViewController.view setHidden:YES];
    [buttonOverlayVC.view setHidden:YES];
    
    // Create an auto-rotating overlay view and its view controller (used for
    // displaying UI objects, such as the camera control menu)
    self.overlayViewController = [[DomOverlayViewController alloc] init];
    [self.parentView addSubview: self.overlayViewController.view];

    self.view = self.parentView;
}

- (void)viewDidLoad
{
    NSLog(@"DomParentVC: loading");
    // it's important to do this from here as arViewController has the wrong idea of orientation
    [self handleARViewRotation:self.interfaceOrientation];
    // we also have to set the overlay view to the correct width/height for the orientation
    [self.overlayViewController handleViewRotation:self.interfaceOrientation];

}

- (void)viewWillAppear:(BOOL)animated 
{
    NSLog(@"DomParentVC: appearing");
    // make sure we're oriented/sized properly before reappearing/restarting
    [self handleARViewRotation:self.interfaceOrientation];
    [self.overlayViewController handleViewRotation:self.interfaceOrientation];
    [self.arViewController viewWillAppear:animated];
}

// This is called on iOS 4 devices (when built with SDK 5.1 or 6.0) and iOS 6
// devices (when built with SDK 5.1)
- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation duration:(NSTimeInterval)duration
{
    // ensure overlay size and AR orientation is correct for screen orientation
    [self.overlayViewController handleViewRotation:self.interfaceOrientation];
    [self handleARViewRotation:interfaceOrientation];
    
    if (YES == [self.arViewController.view isHidden] && UIInterfaceOrientationIsLandscape([self interfaceOrientation])) {
        // iPad - the interface orientation is landscape, so we must switch to
        // the landscape splash image
        [super updateSplashScreenImageForLandscape];
    }
}

- (void) handleARViewRotation:(UIInterfaceOrientation)interfaceOrientation
{
    CGPoint centre, pos;
    NSInteger rot;
    
    // Set the EAGLView's position (its centre) to be the centre of the window, based on orientation
    centre.x = self.arViewController.arViewSize.width / 2;
    centre.y = self.arViewController.arViewSize.height / 2;
    
    BOOL largeScreen = NO ;
      
    if (self.view.frame.size.height > 480) {
        // iPad and iPhone5
        largeScreen = YES;
    }
      
    int yOffset = 200;
    if (YES == largeScreen)
        yOffset = 300;
   
    CGFloat buttonWidth = 70.0;
    CGFloat buttonHeight = 30.0;
    
    CGRect viewBounds;
    viewBounds.origin.x = 0;
    viewBounds.origin.y = 0;
    
    if (interfaceOrientation == UIInterfaceOrientationLandscapeLeft || interfaceOrientation == UIInterfaceOrientationLandscapeRight)
    {
        if (interfaceOrientation == UIInterfaceOrientationLandscapeLeft)
        {
            NSLog(@"DomParentVC: Rotating to Landscape Left"); 
            rot = 180;
        }
        else 
        {
            NSLog(@"DomParentVC: Rotating to Landscape Right");
            rot=0;
        }
        
        isInterfaceOrientationPortrait= false;
        pos.x = centre.y;
        pos.y = centre.x;
        buttonOverlayVC.menuButton.frame = CGRectMake(10,self.view.frame.size.height-yOffset, buttonWidth, buttonHeight);
        buttonOverlayVC.clearButton.frame = CGRectMake(self.view.frame.size.height - 180,self.view.frame.size.width-40, buttonWidth, buttonHeight);
        buttonOverlayVC.resetButton.frame = CGRectMake(self.view.frame.size.height - 100,self.view.frame.size.width-40, buttonWidth, buttonHeight);
        buttonOverlayVC.runButton.frame = CGRectMake(self.view.frame.size.height - 100,self.view.frame.size.width-40, buttonWidth, buttonHeight);
        buttonOverlayVC.deleteButton.frame = CGRectMake(self.view.frame.size.height - 100, 10, buttonWidth, buttonHeight); 
        
        viewBounds.size.width = self.arViewController.arViewSize.height;
        viewBounds.size.height = self.arViewController.arViewSize.width;
        
    }
    else
    {
        if (interfaceOrientation == UIInterfaceOrientationPortrait)
        {
            NSLog(@"DomParentVC: Rotating to Portrait");
            rot = 90;
        }
        else
        {
            NSLog(@"DomParentVC: Rotating to Upside Down");    
            rot = 270;
        }
        isInterfaceOrientationPortrait= true;
        pos = centre;
        buttonOverlayVC.menuButton.frame = CGRectMake(10,self.view.frame.size.height-50, buttonWidth, buttonHeight);
        buttonOverlayVC.clearButton.frame = CGRectMake(self.view.frame.size.width - 160,self.view.frame.size.height-50, buttonWidth, buttonHeight);
        buttonOverlayVC.resetButton.frame = CGRectMake(self.view.frame.size.width - 80,self.view.frame.size.height-50, buttonWidth, buttonHeight);
        buttonOverlayVC.runButton.frame = CGRectMake(self.view.frame.size.width - 80,self.view.frame.size.height-50, buttonWidth, buttonHeight);
        buttonOverlayVC.deleteButton.frame = CGRectMake(self.view.frame.size.width - 80, 10, buttonWidth, buttonHeight);
        
        viewBounds.size.width = self.arViewController.arViewSize.width;
        viewBounds.size.height = self.arViewController.arViewSize.height;
        
    }
    [buttonOverlayVC.view setFrame:viewBounds];
    self.arViewController.arView.layer.position = pos;
    CGAffineTransform rotate = CGAffineTransformMakeRotation(rot * M_PI  / 180);
    self.arViewController.arView.transform = rotate;
}

// Pass touches on to our main touchy/feely view
- (void) touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self.arViewController.arView touchesBegan:touches withEvent:event];
}

- (void) touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self.arViewController.arView touchesMoved:touches withEvent:event];
}

- (void) touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self.arViewController.arView touchesEnded:touches withEvent:event];
}

- (void) touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self.arViewController.arView touchesCancelled:touches withEvent:event];
}

// provoke the menu pop-up
- (void) showMenu
{
    [self.overlayViewController showOverlay];
}

#pragma mark -
#pragma mark Splash screen control
- (void)endSplash:(NSTimer*)theTimer
{
    // Poll to see if the camera video stream has started and if so remove the
    // splash screen
    [super endSplash:theTimer];
    
    if ([Vuforiautils getInstance].videoStreamStarted == YES)
    {
        // Display the button overlay view
        [buttonOverlayVC.view setHidden:NO];
    }
}

@end
