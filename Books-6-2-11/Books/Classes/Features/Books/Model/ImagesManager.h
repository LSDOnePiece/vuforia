/*===============================================================================
Copyright (c) 2012-2015 Qualcomm Connected Experiences, Inc. All Rights Reserved.

Vuforia is a trademark of PTC Inc., registered in the United States and other 
countries.
===============================================================================*/


#import <Foundation/Foundation.h>
#import "ImagesManagerDelegateProtocol.h"


@interface ImagesManager : NSObject <NSURLConnectionDelegate, NSURLConnectionDataDelegate>

@property (nonatomic, strong) NSMutableData *bookImage;
@property (nonatomic, strong) Book *thisBook;
@property (nonatomic, weak) id <ImagesManagerDelegateProtocol> delegate;

@property (readwrite, nonatomic) BOOL cancelNetworkOperation;
@property (readonly, nonatomic) BOOL networkOperationInProgress;

+(id)sharedInstance;
-(void)imageForBook:(Book *)theBook withDelegate:(id <ImagesManagerDelegateProtocol>)aDelegate;
-(UIImage *)cachedImageFromURL:(NSString*)anURLString;

@end
