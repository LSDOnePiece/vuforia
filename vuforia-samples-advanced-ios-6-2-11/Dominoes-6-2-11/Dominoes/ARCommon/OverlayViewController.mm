/*===============================================================================
Copyright (c) 2016 PTC Inc. All Rights Reserved.

Copyright (c) 2012-2014 Qualcomm Connected Experiences, Inc. All Rights Reserved.

Vuforia is a trademark of PTC Inc., registered in the United States and other 
countries.
===============================================================================*/

#import <AVFoundation/AVFoundation.h>
#import <Vuforia/Vuforia.h>
#import <Vuforia/CameraDevice.h>
#import "OverlayViewController.h"
#import "OverlayView.h"
#import "Vuforiautils.h"

@interface OverlayViewController (PrivateMethods)
+ (void) determineCameraCapabilities:(struct tagCameraCapabilities *) pCapabilities;
@end

@implementation OverlayViewController

- (id) init
{
    if ((self = [super init]) != nil)
    {
        selectedTarget = 0;
        vUtils = [Vuforiautils getInstance];
    }
        
    return self;
}


- (void) loadView
{
    CGRect screenBounds = [[UIScreen mainScreen] bounds];
    optionsOverlayView = [[OverlayView alloc] initWithFrame: screenBounds];
    self.view = optionsOverlayView;
    
    // We're going to let the parent VC handle all interactions so disable any UI
    // Further on, we'll also implement a touch pass-through
    self.view.userInteractionEnabled = NO;
}


- (void) handleViewRotation:(UIInterfaceOrientation)interfaceOrientation
{
    // adjust the size according to the rotation
    CGRect screenRect = [[UIScreen mainScreen] bounds];
    CGRect overlayRect = screenRect;
    
    if (interfaceOrientation == UIInterfaceOrientationLandscapeLeft || interfaceOrientation == UIInterfaceOrientationLandscapeRight)
    {
        overlayRect.size.width = screenRect.size.height;
        overlayRect.size.height = screenRect.size.width;
    }
    
    optionsOverlayView.frame = overlayRect;
}


// The user touched the screen - pass through
- (void) touchesBegan: (NSSet*) touches withEvent: (UIEvent*) event
{
    // pass events down to parent VC
    [super touchesBegan:touches withEvent:event];
}


- (void) populateActionSheet
{
    // add flash control button if supported by the device
    if (MENU_OPTION_WANTED == flashIx && YES == cameraCapabilities.torch)
    {
        // set button text according to the current mode (toggle)
        BOOL flashMode = [vUtils cameraTorchOn];
        NSString *text = YES == flashMode ? @"Flash off" : @"Flash on";
        flashIx = [mainOptionsAS addButtonWithTitle:text];
    }
    
    // add focus control button if supported by the device
    if (MENU_OPTION_WANTED == autofocusContIx && YES == cameraCapabilities.autofocusContinuous)
    {
        // set button text according to the current mode (toggle)
        BOOL contAFMode = [vUtils cameraContinuousAFOn];
        NSString *text = YES == contAFMode ? @"Auto focus off" : @"Auto focus on";
        autofocusContIx = [mainOptionsAS addButtonWithTitle:text];
    }
    
    // add single-shot focus control button if supported by the device
    if (MENU_OPTION_WANTED == autofocusSingleIx && YES == cameraCapabilities.autofocus)
    {
        autofocusSingleIx = [mainOptionsAS addButtonWithTitle:@"Focus"];
    }
    
    // add 'select target' if there is more than one target
    if (MENU_OPTION_WANTED == selectTargetIx && vUtils.targetsList && [vUtils.targetsList count] > 1)
    {
        NSInteger targetToShow = (selectedTarget + 1) % [vUtils.targetsList count];
        DataSetItem *targetEntry = [vUtils.targetsList objectAtIndex:targetToShow];
        NSString *text = [NSString stringWithFormat:@"Switch to %@", targetEntry.name];
        selectTargetIx = [mainOptionsAS addButtonWithTitle:text];
    }
    
    // The cancel button is added in showOverlay rather than here.  This enables
    // a subclass to call [super populateActionSheet either before or after adding
    // its own items
}


// pop-up is invoked by parent VC
- (void) showOverlay
{
    // Get the camera capabilities
    [OverlayViewController determineCameraCapabilities:&cameraCapabilities];
    
    // Show camera control action sheet
    mainOptionsAS = [[UIActionSheet alloc] initWithTitle:nil
                                                  delegate:self
                                         cancelButtonTitle:nil
                                    destructiveButtonTitle:nil
                                         otherButtonTitles:nil];
    
    // Specify standard menu options... a subclass can alter these settings
    // in populateActionSheet
    autofocusContIx = MENU_OPTION_WANTED;
    autofocusSingleIx = MENU_OPTION_UNWANTED;
    selectTargetIx = MENU_OPTION_WANTED;
    flashIx = MENU_OPTION_UNWANTED;
    
    // Call myself to populate the menu.  May be overridden.
    [self populateActionSheet];
 
    // Only show the menu if we ended up with something in it
    if ([mainOptionsAS numberOfButtons] > 0)
    {
        // Add a cancel button (this is only shown by iOS in the Phone idiom)
        [mainOptionsAS setCancelButtonIndex:[mainOptionsAS addButtonWithTitle:@"Cancel"]];
        self.view.userInteractionEnabled = YES;
        [mainOptionsAS showInView:self.view];
    }
}


// check to see if any content would be shown in showOverlay
+ (BOOL) doesOverlayHaveContent
{
    int count = 0;
    
    struct tagCameraCapabilities capabilities;
    [OverlayViewController determineCameraCapabilities:&capabilities];
    
    if (YES == capabilities.autofocusContinuous)
        ++count;
    
    if ([Vuforiautils getInstance].targetsList && [[Vuforiautils getInstance].targetsList count] > 1)
        ++count;
    
    return (count > 0);
}


// UIActionSheetDelegate event handlers

- (void) mainOptionClickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (flashIx == buttonIndex)
    {
        BOOL newFlashMode = ![vUtils cameraTorchOn];
        [vUtils cameraSetTorchMode:newFlashMode];
    }
    else if (selectTargetIx == buttonIndex)
    {
        selectedTarget = (selectedTarget + 1) % [vUtils.targetsList count];        
        DataSetItem *targetEntry = [vUtils.targetsList objectAtIndex:selectedTarget];
        [vUtils activateDataSet:targetEntry.dataSet];
    }
    else if (autofocusContIx == buttonIndex)
    {
        // toggle camera continuous autofocus mode
        BOOL newContAFMode = ![vUtils cameraContinuousAFOn];
        [vUtils cameraSetContinuousAFMode:newContAFMode];
    }
    else if (autofocusSingleIx == buttonIndex)
    {
        [vUtils cameraPerformAF];
    }
        
    self.view.userInteractionEnabled = NO;
 }


- (void) actionSheet:(UIActionSheet*)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    [self mainOptionClickedButtonAtIndex:buttonIndex];
}


+ (void) determineCameraCapabilities:(struct tagCameraCapabilities *) pCapabilities
{
    // Determine whether the cameras support torch and autofocus
    NSArray* cameraArray = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    vUtils.noOfCameras = [cameraArray count];
    AVCaptureDevicePosition cameraPosition = AVCaptureDevicePositionBack;
    
    if (Vuforia::CameraDevice::CAMERA_DIRECTION_FRONT == vUtils.activeCamera)
    {
        cameraPosition = AVCaptureDevicePositionFront;
    }
    
    for (AVCaptureDevice* camera in cameraArray)
    {
        if (cameraPosition == [camera position])
        {
            pCapabilities->autofocus = [camera isFocusModeSupported:AVCaptureFocusModeAutoFocus];
            pCapabilities->autofocusContinuous = [camera isFocusModeSupported:AVCaptureFocusModeContinuousAutoFocus];
            pCapabilities->torch = [camera isTorchModeSupported:AVCaptureTorchModeOn];
        }
    }
}


@end
