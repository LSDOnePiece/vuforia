/*===============================================================================
Copyright (c) 2012-2014 Qualcomm Connected Experiences, Inc. All Rights Reserved.

Vuforia is a trademark of PTC Inc., registered in the United States and other 
countries.
===============================================================================*/

#import <UIKit/UIKit.h>
#import "EAGLView.h"


@interface ButtonOverlayViewController : UIViewController {
    id menuId;
    SEL menuSel;
}

@property (nonatomic, strong) UIButton* menuButton;
@property (nonatomic, strong) UIButton* resetButton;
@property (nonatomic, strong) UIButton* runButton;
@property (nonatomic, strong) UIButton* clearButton;
@property (nonatomic, strong) UIButton* deleteButton;
@property (nonatomic, strong) UILabel* messageLabel;
@property (nonatomic, strong) NSTimer* messageTimer;

- (void) setMenuCallBack:(SEL)callback forTarget:(id)target;

- (void) pressMenuButton;
- (void) pressResetButton;
- (void) pressRunButton;
- (void) pressClearButton;
- (void) pressDeleteButton;

- (void) showDeleteButton;
- (void) hideDeleteButton;
- (void) showMessage:(NSString *)theMessage;
- (void) hideMessage;

@end
