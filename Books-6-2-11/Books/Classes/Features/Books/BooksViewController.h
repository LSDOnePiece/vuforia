/*===============================================================================
Copyright (c) 2012-2015 Qualcomm Connected Experiences, Inc. All Rights Reserved.

Vuforia is a trademark of PTC Inc., registered in the United States and other 
countries.
===============================================================================*/

#import <UIKit/UIKit.h>
#import "BooksEAGLView.h"
#import "SampleApplicationSession.h"
#import "BooksOverlayViewController.h"
#import "BookWebDetailViewController.h"
#import "Book.h"

@class TargetOverlayView;

@interface BooksViewController : UIViewController <SampleApplicationControl, BooksControllerDelegateProtocol, UIGestureRecognizerDelegate, UIAlertViewDelegate>
{
    id backgroundObserver;
    id activeObserver;
    int lastErrorCode;
}

@property (nonatomic, strong) BooksEAGLView* eaglView;
@property (nonatomic, strong) UITapGestureRecognizer * tapGestureRecognizer;
@property (nonatomic, strong) SampleApplicationSession * vapp;

@property (nonatomic, strong) NSString * lastTargetIDScanned;
@property (nonatomic, strong) Book *lastScannedBook;
@property (nonatomic, strong) BooksOverlayViewController * bookOverlayController;
@property (nonatomic, weak) BookWebDetailViewController * bookWebDetailController;

@end
