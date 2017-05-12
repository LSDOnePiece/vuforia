/*===============================================================================
Copyright (c) 2012-2014 Qualcomm Connected Experiences, Inc. All Rights Reserved.

Vuforia is a trademark of PTC Inc., registered in the United States and other 
countries.
===============================================================================*/


#import "AR_EAGLView.h"
// This class wraps the CAEAGLLayer from CoreAnimation into a convenient UIView
// subclass.  The view content is basically an EAGL surface you render your
// OpenGL scene into.  Note that setting the view non-opaque will only work if
// the EAGL surface has an alpha channel.
@interface EAGLView : AR_EAGLView
{
}

- (void)updateRenderingPrimitives;

@end
