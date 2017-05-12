/*===============================================================================
Copyright (c) 2012-2015 Qualcomm Connected Experiences, Inc. All Rights Reserved.
 
Confidential and Proprietary - Protected under copyright and other laws.
Vuforia is a trademark of PTC Inc., registered in the United States and other 
countries.
===============================================================================*/


#import "Book.h"

@implementation Book
@synthesize ratingsQuantity, ratingAverage, listPrice, yourPrice, title, author, targetID, thumbnailURL, bookURL;

#pragma mark - Public

-(id)initWithDictionary:(NSDictionary *)aDictionary
{
    self = [super init];
    if (self)
    {
        self.targetID = [aDictionary objectForKey:@"targetid"];
        self.ratingsQuantity = [[aDictionary objectForKey:@"# of ratings"] integerValue];
        self.ratingAverage = [[aDictionary objectForKey:@"average rating"] floatValue];
        self.listPrice = [[aDictionary objectForKey:@"list price"] floatValue];
        self.yourPrice = [[aDictionary objectForKey:@"your price"] floatValue];
        self.title = [aDictionary objectForKey:@"title"];
        self.author = [aDictionary objectForKey:@"author"];
        self.thumbnailURL = [aDictionary objectForKey:@"thumburl"];
        self.bookURL = [aDictionary objectForKey:@"bookurl"];
    }
    
    return self;
}

#pragma mark - Properties

-(NSString *)yourPriceString
{
    NSString *retVal = [NSString stringWithFormat:@"$%.2f", yourPrice];
    return retVal;
}

-(NSString *)listPriceString
{
    NSString *retVal = [NSString stringWithFormat:@"$%.2f", listPrice];
    return retVal;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"%@ ::: %@ - %@ - %@ - %@ - %f (%ld)", [super description], self.title, self.author, self.listPriceString, self.yourPriceString, self.ratingAverage, (long)self.ratingsQuantity];
}
@end
