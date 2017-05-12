/*===============================================================================
Copyright (c) 2012-2015 Qualcomm Connected Experiences, Inc. All Rights Reserved.

Vuforia is a trademark of PTC Inc., registered in the United States and other 
countries.
===============================================================================*/


#import <Foundation/Foundation.h>
#import "Book.h"

//  IMPORTANT: BookDataParser is written to parse data specific to the Books
//  sample application and is not designed to be used in other applications.

@interface BookDataParser : NSObject

+(NSDictionary *)parseData:(NSData *)dataToParse;
+(NSDictionary *)parseString:(NSString *)stringToParse;

@end
