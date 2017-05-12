/*===============================================================================
Copyright (c) 2012-2014 Qualcomm Connected Experiences, Inc. All Rights Reserved.

Vuforia is a trademark of PTC Inc., registered in the United States and other 
countries.
===============================================================================*/

#import <Foundation/Foundation.h>

@interface Texture : NSObject {
    int width;
    int height;
    int channels;
    int textureID;
    unsigned char* pngData;
}

@property (nonatomic, readonly) int width;
@property (nonatomic, readonly) int height;
@property (nonatomic) int textureID;
@property (nonatomic, readonly) unsigned char* pngData;

- (BOOL)loadImage:(NSString*)filename;

@end
