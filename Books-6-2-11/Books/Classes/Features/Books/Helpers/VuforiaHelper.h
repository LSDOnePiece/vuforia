/*===============================================================================
Copyright (c) 2016 PTC Inc. All Rights Reserved.

Copyright (c) 2012-2015 Qualcomm Connected Experiences, Inc. All Rights Reserved.

Vuforia is a trademark of PTC Inc., registered in the United States and other 
countries.
===============================================================================*/


#import <UIKit/UIKit.h>

typedef enum {
    kTargetStatusRequesting,
    kTargetStatusNone
} TargetStatus;

@interface VuforiaHelper : NSObject

+(TargetStatus)targetStatus;
+(NSString*) errorStringFromCode:(int) code;

+ (void) startDetection;
+ (void) stopDetection;

+ (BOOL) isRetinaDevice;
@end
