/*===============================================================================
Copyright (c) 2016 PTC Inc. All Rights Reserved.

Copyright (c) 2012-2014 Qualcomm Connected Experiences, Inc. All Rights Reserved.

Vuforia is a trademark of PTC Inc., registered in the United States and other 
countries.
===============================================================================*/

#import <UIKit/UIKit.h>
@class EAGLView, Vuforiautils;

@interface ARViewController : UIViewController {
@public
    IBOutlet EAGLView *arView;  // the Augmented Reality view
    CGSize arViewSize;          // required view size

@protected
    Vuforiautils *vUtils;          // Vuforia utils singleton class
@private
    UIView *parentView;         // Avoids unwanted interactions between UIViewController and EAGLView
    NSMutableArray* textures;   // Teapot textures
    BOOL arVisible;             // State of visibility of the view
}

@property (nonatomic, strong) IBOutlet EAGLView *arView;
@property (nonatomic) CGSize arViewSize;
           
- (void) handleARViewRotation:(UIInterfaceOrientation)interfaceOrientation;
- (void)freeOpenGLESResources;

@end
