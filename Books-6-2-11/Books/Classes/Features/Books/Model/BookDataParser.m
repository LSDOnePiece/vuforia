/*===============================================================================
Copyright (c) 2012-2015 Qualcomm Connected Experiences, Inc. All Rights Reserved.
 
Confidential and Proprietary - Protected under copyright and other laws.
Vuforia is a trademark of PTC Inc., registered in the United States and other 
countries.
===============================================================================*/


#import "BookDataParser.h"
#import "Book.h"

static const NSString *kBookParseTitleKey = @"title";
static const NSString *kBookParseAuthorKey = @"author";
static const NSString *kBookParseAverageRatingKey = @"average rating";
static const NSString *kBookParseNumberOfRatingsKey = @"# of ratings";
static const NSString *kBookParseListPriceKey = @"list price";
static const NSString *kBookParseYourPriceKey = @"your price";
static const NSString *kBookParseThumbUrlKey = @"thumburl";
static const NSString *kBookParseUrlKey = @"bookurl";


@implementation BookDataParser

#pragma mark - Private

+(NSString *)stringBetweenDoubleQuotes:(NSString *)val
{
    NSString *retVal = nil;
    
    //  Get index of first quote
    NSInteger initialIndex = [val rangeOfString:@"\""].location;
    
    //  Get index of last quote
    NSRange rangeForFinalIndex = NSMakeRange(initialIndex+1, [val length] - initialIndex - 1);
    NSInteger finalIndex = [val rangeOfString:@"\"" options:NSLiteralSearch range:rangeForFinalIndex].location;
    
    //  Get range of string between quotes
    NSRange substringRange = NSMakeRange(initialIndex+1, finalIndex - initialIndex -1);

    //  Get substring
    retVal = [val substringWithRange:substringRange];
    return retVal;
}

+(NSString *)keyFromLine:(NSString *)aJSONLine
{
    NSArray *elements = [aJSONLine componentsSeparatedByString:@":"];
    NSString *retVal = [BookDataParser stringBetweenDoubleQuotes:[elements objectAtIndex:0]];
    return retVal;
}

+(NSString *)valueFromLine:(NSString *)aJSONLine isURL:(BOOL)isURL
{
    NSArray *elements = [aJSONLine componentsSeparatedByString:@":"];
    NSString *stringToTransform = nil;

    if (isURL)
    {
        stringToTransform = [NSString stringWithFormat:@"%@:%@", [elements objectAtIndex:1], [elements objectAtIndex:2]];
    }
    else
    {
        stringToTransform = [elements objectAtIndex:1];
    }
    
    NSString *retVal = [BookDataParser stringBetweenDoubleQuotes:stringToTransform];
    return retVal;
}

#pragma mark - Public

+(NSDictionary *)parseData:(NSData *)dataToParse
{
    NSString *stringToParse = [[NSString alloc] initWithData:dataToParse encoding:NSUTF8StringEncoding];
    NSDictionary *retVal = [BookDataParser parseString:stringToParse];
    return retVal;
}

+(NSDictionary *)parseString:(NSString *)stringToParse
{    
    NSMutableDictionary *tmpDict = [[NSMutableDictionary alloc] init];
    
    NSArray *jsonLines = [stringToParse componentsSeparatedByString:@","];
    
    for(NSString *line in jsonLines)
    {
        NSString *jsonKey = [BookDataParser keyFromLine:line];
        NSString *jsonValue = nil;
        
        if ([jsonKey isEqualToString:kBookParseThumbUrlKey] ||
            [jsonKey isEqualToString:kBookParseUrlKey])
        {
            jsonValue = [BookDataParser valueFromLine:line isURL:YES];
        }
        else
        {
            jsonValue = [BookDataParser valueFromLine:line isURL:NO];
        }
        
        [tmpDict setObject:jsonValue forKey:jsonKey];
    }
    
    NSDictionary *retVal = [NSDictionary dictionaryWithDictionary:tmpDict];
    return retVal;
}

@end
