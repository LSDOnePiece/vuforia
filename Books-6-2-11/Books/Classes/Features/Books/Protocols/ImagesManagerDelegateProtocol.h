/*===============================================================================
Copyright (c) 2012-2015 Qualcomm Connected Experiences, Inc. All Rights Reserved.

Vuforia is a trademark of PTC Inc., registered in the United States and other 
countries.
===============================================================================*/

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "Book.h"

@protocol ImagesManagerDelegateProtocol <NSObject>

-(void)imageRequestDidFinishForBook:(Book *)theBook withImage:(UIImage *)anImage byCancelling:(BOOL)cancelled;

@end
