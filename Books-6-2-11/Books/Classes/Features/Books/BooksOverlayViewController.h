/*===============================================================================
Copyright (c) 2012-2015 Qualcomm Connected Experiences, Inc. All Rights Reserved.

Vuforia is a trademark of PTC Inc., registered in the United States and other 
countries.
===============================================================================*/

#import "BooksControllerDelegateProtocol.h"
#import <UIKit/UIKit.h>

@class TargetOverlayView;

// OverlayViewController class overrides one UIViewController method
@interface BooksOverlayViewController : UIViewController

@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIButton *closeButton;
@property (nonatomic, strong) NSTimer *statusTimer;

@property (nonatomic, strong) UIView *optionsOverlayView; // the view for the options pop-up
@property (nonatomic, strong) UIView *loadingView;

@property (nonatomic, weak) id <BooksControllerDelegateProtocol> booksDelegate;

- (id)initWithDelegate:(id<BooksControllerDelegateProtocol>) delegate;

- (void) handleViewRotation:(UIInterfaceOrientation)interfaceOrientation;

- (void) killTimer;

@property (nonatomic, strong) IBOutlet TargetOverlayView *targetOverlayView;

@end
