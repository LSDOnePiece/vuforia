/*===============================================================================
Copyright (c) 2016 PTC Inc. All Rights Reserved.

Copyright (c) 2012-2014 Qualcomm Connected Experiences, Inc. All Rights Reserved.

Vuforia is a trademark of PTC Inc., registered in the United States and other 
countries.
===============================================================================*/


#import <QuartzCore/QuartzCore.h>
#import "AR_EAGLView.h"
#import "Texture.h"
#import <Vuforia/Vuforia.h>
#import <Vuforia/VideoBackgroundConfig.h>
#import "Vuforiautils.h"

#import "ShaderUtils.h"
#define MAKESTRING(x) #x
#import "Shaders/Shader.fsh"
#import "Shaders/Shader.vsh"


@implementation Object3D

@synthesize numVertices;
@synthesize vertices;
@synthesize normals;
@synthesize texCoords;
@synthesize numIndices;
@synthesize indices;
@synthesize texture;

@end

@interface AR_EAGLView (PrivateMethods)
- (void)setFramebuffer;
- (BOOL)presentFramebuffer;
- (void)createFramebuffer;
- (void)deleteFramebuffer;
- (int)loadTextures;
- (void)initRendering;
@end


@implementation AR_EAGLView

@synthesize textureList;

// You must implement this method
+ (Class)layerClass
{
    return [CAEAGLLayer class];
}

// test to see if the screen has hi-res mode
- (BOOL) isRetinaEnabled
{
    return ([[UIScreen mainScreen] respondsToSelector:@selector(displayLinkWithTarget:selector:)]
            &&
            ([UIScreen mainScreen].scale == 2.0));
}

// use to allow this view to access loaded textures
- (void) useTextures:(NSMutableArray *)theTextures
{
    textures = theTextures;
}
 

#pragma mark ---- view lifecycle ---
/////////////////////////////////////////////////////////////////
//
- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    
	if (self) {
        vUtils = [Vuforiautils getInstance];
        objects3D = [[NSMutableArray alloc] initWithCapacity:2];
        textureList = [[NSMutableArray alloc] initWithCapacity:2];
        
        // switch on hi-res mode if available
        if ([self isRetinaEnabled])
        {
            self.contentScaleFactor = 2.0f;
            vUtils.contentScalingFactor = self.contentScaleFactor;
        }
        
        CAEAGLLayer *eaglLayer = (CAEAGLLayer *)self.layer;
        
        eaglLayer.opaque = TRUE;
        eaglLayer.drawableProperties = [NSDictionary dictionaryWithObjectsAndKeys:
                                        [NSNumber numberWithBool:FALSE], kEAGLDrawablePropertyRetainedBacking,
                                        kEAGLColorFormatRGBA8, kEAGLDrawablePropertyColorFormat,
                                        nil];
        
        context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
        vUtils.VuforiaFlags = Vuforia::GL_20;
        
        NSLog(@"Vuforia OpenGL flag: %d", vUtils.VuforiaFlags);
        
        if (!context) {
            NSLog(@"Failed to create ES context");
        }
    }
    
    return self;
}

- (void)dealloc
{
    [self deleteFramebuffer];
    
    // Tear down context
    if ([EAGLContext currentContext] == context) {
        [EAGLContext setCurrentContext:nil];
    }
}

- (void)finishOpenGLESCommands
{
    // Called in response to applicationWillResignActive.  The ARViewController
    // stops the render loop, and we now make sure all OpenGL ES commands
    // complete before we (potentially) go into the background
    if (context) {
        [EAGLContext setCurrentContext:context];
        glFinish();
    }
}

- (void)freeOpenGLESResources
{
    // Called in response to applicationDidEnterBackground.  Free easily
    // recreated OpenGL ES resources
    [self deleteFramebuffer];
    glFinish();
}


/////////////////////////////////////////////////////////////////
//
- (void)layoutSubviews
{
    NSLog(@"EAGLView: layoutSubviews");
    
    // The framebuffer will be re-created at the beginning of the next setFramebuffer method call.
    [self deleteFramebuffer];
    
    // Initialisation done once, or once per screen size change
    [self initRendering];
}


#pragma mark --- OpenGL essentials ---
/////////////////////////////////////////////////////////////////
//
- (void)createFramebuffer
{

    if (context && !defaultFramebuffer) {
        [EAGLContext setCurrentContext:context];
        
        // Create default framebuffer object
        glGenFramebuffers(1, &defaultFramebuffer);
        glBindFramebuffer(GL_FRAMEBUFFER, defaultFramebuffer);
        
        // Create colour render buffer and allocate backing store
        glGenRenderbuffers(1, &colorRenderbuffer);
        glBindRenderbuffer(GL_RENDERBUFFER, colorRenderbuffer);

        // Allocate the renderbuffer's storage (shared with the drawable object)
        [context renderbufferStorage:GL_RENDERBUFFER fromDrawable:(CAEAGLLayer *)self.layer];
        glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &framebufferWidth);
        glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &framebufferHeight);
        
        // Create the depth render buffer and allocate storage
        glGenRenderbuffers(1, &depthRenderbuffer);
        glBindRenderbuffer(GL_RENDERBUFFER, depthRenderbuffer);
        glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT16, framebufferWidth, framebufferHeight);
        
        // Attach colour and depth render buffers to the frame buffer
        glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, colorRenderbuffer);
        glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, depthRenderbuffer);
        
        // Leave the colour render buffer bound so future rendering operations will act on it
        glBindRenderbuffer(GL_RENDERBUFFER, colorRenderbuffer);
        
        if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE) {
            NSLog(@"Failed to make complete framebuffer object %x", glCheckFramebufferStatus(GL_FRAMEBUFFER));
        }
    }
}


/////////////////////////////////////////////////////////////////
//
- (void)deleteFramebuffer
{
    if (context) {
        [EAGLContext setCurrentContext:context];
        
        if (defaultFramebuffer) {
            glDeleteFramebuffers(1, &defaultFramebuffer);
            defaultFramebuffer = 0;
        }
        
        if (colorRenderbuffer) {
            glDeleteRenderbuffers(1, &colorRenderbuffer);
            colorRenderbuffer = 0;
        }
        
        if (depthRenderbuffer) {
            glDeleteRenderbuffers(1, &depthRenderbuffer);
            depthRenderbuffer = 0;
        }
    }
}


/////////////////////////////////////////////////////////////////
//
- (void)setFramebuffer
{
    if (context) {
        [EAGLContext setCurrentContext:context];
        
        if (!defaultFramebuffer) {
            // Perform on the main thread to ensure safe memory allocation for
            // the shared buffer.  Block until the operation is complete to
            // prevent simultaneous access to the OpenGL context
            [self performSelectorOnMainThread:@selector(createFramebuffer) withObject:self waitUntilDone:YES];
        }
        
        glBindFramebuffer(GL_FRAMEBUFFER, defaultFramebuffer);
    }
}


/////////////////////////////////////////////////////////////////
//
- (BOOL)presentFramebuffer
{
    BOOL success = FALSE;
    
    if (context) {
        [EAGLContext setCurrentContext:context];
        
        glBindRenderbuffer(GL_RENDERBUFFER, colorRenderbuffer);
        
        success = [context presentRenderbuffer:GL_RENDERBUFFER];
    }
    
    return success;
}


/////////////////////////////////////////////////////////////////
// TEMPLATE - this is app specific and
// expected to be overridden in EAGLView.mm
- (void) setup3dObjects
{
    for (int i=0; i < [textures count]; i++)
    {
        Object3D *obj3D = [[Object3D alloc] init];

        obj3D.numVertices = 0;
        obj3D.vertices = nil;
        obj3D.normals = nil;
        obj3D.texCoords = nil;
        
        obj3D.numIndices = 0;
        obj3D.indices = nil;
        
        obj3D.texture = [textures objectAtIndex:i];

        [objects3D addObject:obj3D];
    }
}


////////////////////////////////////////////////////////////////////////////////
// Initialise OpenGL 2.x shaders
- (void)initShaders
{
    // OpenGL 2 initialisation
    shaderProgramID = ShaderUtils::createProgramFromBuffer(vertexShader, fragmentShader);
    
    if (0 < shaderProgramID) {
        vertexHandle = glGetAttribLocation(shaderProgramID, "vertexPosition");
        normalHandle = glGetAttribLocation(shaderProgramID, "vertexNormal");
        textureCoordHandle = glGetAttribLocation(shaderProgramID, "vertexTexCoord");
        mvpMatrixHandle = glGetUniformLocation(shaderProgramID, "modelViewProjectionMatrix");
        texSampler2DHandle  = glGetUniformLocation(shaderProgramID,"texSampler2D");
    }
    else {
        NSLog(@"Could not initialise augmentation shader");
    }
}


////////////////////////////////////////////////////////////////////////////////
// Initialise OpenGL rendering
- (void)initRendering
{
    if (renderingInited)
        return;
    
    // Define the clear colour
    glClearColor(0.0f, 0.0f, 0.0f, Vuforia::requiresAlpha() ? 0.0f : 1.0f);
    
    // Generate the OpenGL texture objects
    for (int i = 0; i < [textures count]; ++i) {
        GLuint nID;
        Texture* texture = [textures objectAtIndex:i];
        glGenTextures(1, &nID);
        [texture setTextureID: nID];
        glBindTexture(GL_TEXTURE_2D, nID);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, [texture width], [texture height], 0, GL_RGBA, GL_UNSIGNED_BYTE, (GLvoid*)[texture pngData]);
    }
    
    // set up objects using the above textures.
    [self setup3dObjects];
    
    if (Vuforia::GL_20 & vUtils.VuforiaFlags) {
        [self initShaders];
    }
    
    renderingInited = YES;
}


////////////////////////////////////////////////////////////////////////////////
// Draw the current frame using OpenGL
//
// This code is a TEMPLATE for the subclassing EAGLView to complete
//
// The subclass override of this method is called by Vuforia when it wishes to render the current frame to
// the screen.
//
// *** Vuforia will call the subclassed method on a single background thread ***
- (void)renderFrameVuforia
{
}

@end
