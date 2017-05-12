/*===============================================================================
Copyright (c) 2016 PTC Inc. All Rights Reserved.

Copyright (c) 2012-2015 Qualcomm Connected Experiences, Inc. All Rights Reserved.

Vuforia is a trademark of PTC Inc., registered in the United States and other 
countries.
===============================================================================*/


#import "VuforiaHelper.h"

//#import "EAGLView.h"
#import "Texture.h"
#include <Vuforia/Vuforia.h>
#include <Vuforia/TrackerManager.h>
#include <Vuforia/ObjectTracker.h>
#include <Vuforia/ImageTarget.h>
#include <Vuforia/DataSet.h>
#include <Vuforia/TargetFinder.h>
#include <Vuforia/TargetSearchResult.h>

@implementation VuforiaHelper

#pragma mark - Private

+(void)toggleDetection:(BOOL)isEnabled
{
    //  Starts / Stops Target and Books recognition
    
    Vuforia::TrackerManager& trackerManager = Vuforia::TrackerManager::getInstance();
    Vuforia::ObjectTracker* objectTracker = static_cast<Vuforia::ObjectTracker*>(
                                                                        trackerManager.getTracker(Vuforia::ObjectTracker::getClassType()));
    assert(objectTracker != 0);
    
    Vuforia::TargetFinder* targetFinder = objectTracker->getTargetFinder();
    assert (targetFinder != 0);

    
    if (isEnabled)
    {
        objectTracker->start();
        targetFinder->startRecognition();
    }
    else
    {
        objectTracker->stop();
        targetFinder->stop();
    }
}

#pragma mark - Public

+(TargetStatus)targetStatus
{
    TargetStatus retVal = kTargetStatusNone;
    
    // Get the tracker manager:
    Vuforia::TrackerManager& trackerManager = Vuforia::TrackerManager::getInstance();
    
    // Get the image tracker:
    Vuforia::ObjectTracker* objectTracker = static_cast<Vuforia::ObjectTracker*>(trackerManager.getTracker(Vuforia::ObjectTracker::getClassType()));
    
    // Get the target finder:
    if (objectTracker)
    {
        Vuforia::TargetFinder* finder = objectTracker->getTargetFinder();
        
        if (finder && finder->isRequesting())
        {
            retVal = kTargetStatusRequesting;
        }
    }
    
    return retVal;
}

+ (NSString*) errorStringFromCode:(int) code{
    
    NSString* errorMessage = [NSString stringWithUTF8String:"Unknown error occured"];
    if (code == Vuforia::TargetFinder::UPDATE_ERROR_AUTHORIZATION_FAILED)
        errorMessage=@"Error: AUTHORIZATION_FAILED";
    if (code == Vuforia::TargetFinder::UPDATE_ERROR_PROJECT_SUSPENDED)
        errorMessage=@"Error: PROJECT_SUSPENDED";
    if (code == Vuforia::TargetFinder::UPDATE_ERROR_NO_NETWORK_CONNECTION)
        errorMessage=@"Error: NO_NETWORK_CONNECTION";
    if (code == Vuforia::TargetFinder::UPDATE_ERROR_SERVICE_NOT_AVAILABLE)
        errorMessage=@"Error: SERVICE_NOT_AVAILABLE";
    if (code == Vuforia::TargetFinder::UPDATE_ERROR_BAD_FRAME_QUALITY)
        errorMessage=@"Error: BAD_FRAME_QUALITY";
    if (code == Vuforia::TargetFinder::UPDATE_ERROR_UPDATE_SDK)
        errorMessage=@"Error: UPDATE_SDK";
    if (code == Vuforia::TargetFinder::UPDATE_ERROR_TIMESTAMP_OUT_OF_RANGE)
        errorMessage=@"Error: TIMESTAMP_OUT_OF_RANGE";
    if (code == Vuforia::TargetFinder::UPDATE_ERROR_REQUEST_TIMEOUT)
        errorMessage=@"Error: REQUEST_TIMEOUT";
    
    return errorMessage;
}

+ (void) stopDetection
{
    [VuforiaHelper toggleDetection:NO];
}

+ (void) startDetection
{
    [VuforiaHelper toggleDetection:YES];
}

+ (BOOL) isRetinaDevice
{
    BOOL retVal = ([[UIScreen mainScreen] respondsToSelector:@selector(displayLinkWithTarget:selector:)] &&
                   ([UIScreen mainScreen].scale > 1.0));
    return retVal;
}

@end
