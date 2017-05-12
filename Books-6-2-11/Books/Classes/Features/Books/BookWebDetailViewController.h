/*===============================================================================
Copyright (c) 2012-2015 Qualcomm Connected Experiences, Inc. All Rights Reserved.

Vuforia is a trademark of PTC Inc., registered in the United States and other 
countries.
===============================================================================*/


#import <UIKit/UIKit.h>
#import "Book.h"

@interface BookWebDetailViewController : UIViewController

@property (nonatomic, weak) IBOutlet UIWebView *webView;
@property (strong) Book *book;

@end
