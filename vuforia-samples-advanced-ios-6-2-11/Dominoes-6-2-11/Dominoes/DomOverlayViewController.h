/*===============================================================================
Copyright (c) 2012-2014 Qualcomm Connected Experiences, Inc. All Rights Reserved.

Vuforia is a trademark of PTC Inc., registered in the United States and other 
countries.
===============================================================================*/


#import <Foundation/Foundation.h>
#import "OverlayViewController.h"

//  DomOverlayViewController overrides populateActionSheet method to add
//  single-shot autofocus functionality

@interface DomOverlayViewController : OverlayViewController <UIActionSheetDelegate>
{
}

@end
