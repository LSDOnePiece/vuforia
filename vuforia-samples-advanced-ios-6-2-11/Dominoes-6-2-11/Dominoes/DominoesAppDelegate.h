/*===============================================================================
Copyright (c) 2012-2014 Qualcomm Connected Experiences, Inc. All Rights Reserved.

Vuforia is a trademark of PTC Inc., registered in the United States and other 
countries.
===============================================================================*/

#import <UIKit/UIKit.h>
#import "EAGLView.h"

@class ARParentViewController;
    
    
@interface DominoesAppDelegate : NSObject <UIApplicationDelegate>

@property (nonatomic, strong) UIWindow* window;
@property (nonatomic, strong) ARParentViewController* arParentViewController;

@end
