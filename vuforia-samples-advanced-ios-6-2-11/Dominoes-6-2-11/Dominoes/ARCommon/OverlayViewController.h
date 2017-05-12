/*===============================================================================
Copyright (c) 2016 PTC Inc. All Rights Reserved.

Copyright (c) 2012-2014 Qualcomm Connected Experiences, Inc. All Rights Reserved.

Vuforia is a trademark of PTC Inc., registered in the United States and other 
countries.
===============================================================================*/

#import <UIKit/UIKit.h>

@class Vuforiautils;

// OverlayViewController class overrides one UIViewController method
@interface OverlayViewController : UIViewController <UIActionSheetDelegate> 
{
@protected
    UIView *optionsOverlayView; // the view for the options pop-up
    UIActionSheet *mainOptionsAS; // the options menu
    NSInteger selectedTarget; // remember the selected target so we can mark it
    NSInteger selectTargetIx; // index of the option that is 'Select Target'
    NSInteger autofocusContIx;  // index of camera continuous autofocus button
    NSInteger autofocusSingleIx; // index of single-shot autofocus button (not used on most samples)
    NSInteger flashIx;  // index of camera flash button (not used on most samples)
    
    struct tagCameraCapabilities {
        BOOL autofocus;
        BOOL autofocusContinuous;
        BOOL torch;	
    } cameraCapabilities;
    
    enum { MENU_OPTION_WANTED = -1, MENU_OPTION_UNWANTED = -2 };
    
    Vuforiautils *vUtils;
}

- (void) handleViewRotation:(UIInterfaceOrientation)interfaceOrientation;
- (void) showOverlay;
- (void) populateActionSheet;
+ (BOOL) doesOverlayHaveContent;

// UIActionSheetDelegate event handlers (accessible by subclasses)
- (void) mainOptionClickedButtonAtIndex:(NSInteger)buttonIndex;

@end
