//
//  OpenGLView.m
//  GLCameraTemplate
//
//  Created by kazuki_tanaka on 2013/05/01.
//  Copyright (c) 2013年 kazukitanaka. All rights reserved.
//

#import "OpenGLView.h"

#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>
#import <QuartzCore/QuartzCore.h>

@interface OpenGLView()

@property (nonatomic, strong) EAGLContext *context;

@end

@implementation OpenGLView

+ (Class)layerClass
{
    return [CAEAGLLayer class];
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code

        CAEAGLLayer *eaglLayer = (CAEAGLLayer *)self.layer;
        eaglLayer.opaque = YES;
        eaglLayer.drawableProperties = @{
                                         kEAGLDrawablePropertyRetainedBacking : @ (YES),
                                         kEAGLDrawablePropertyColorFormat : kEAGLColorFormatRGBA8
                                         };
        self.context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];

        if (!self.context
        ||  ![EAGLContext setCurrentContext:self.context]
        ||  ![self createFrameBuffers]
        )
        {
            return nil;
        }
    }
    return self;
}

- (BOOL)createFrameBuffers
{
    glEnable(GL_TEXTURE_2D);
    glDisable(GL_DEPTH_TEST);

    // framebuffer
    GLuint fremebuffer = 0;
    glGenFramebuffers(1, &fremebuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, fremebuffer);

    // renderbuffer
    GLuint renderbuffer = 0;
    glGenRenderbuffers(1, &renderbuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, renderbuffer);

    [self.context renderbufferStorage:GL_RENDERBUFFER fromDrawable:(CAEAGLLayer *)self.layer];

    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, renderbuffer);
    if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE)
    {
        return NO;
    }

    if (![self loadShader])
    {
        return NO;
    }
    
    return YES;
}

- (GLuint)compileShader:(NSString *)shaderString shardrType:(GLenum)shaderType
{
    const GLchar *source = (GLchar *)[shaderString UTF8String];

    if (!source)
    {
        exit(1);
    }

    GLuint shader = glCreateShader(shaderType);
    glShaderSource(shader, 1, &source, NULL);
    glCompileShader(shader);

    GLint status = 0;
    glGetShaderiv(shader, GL_COMPILE_STATUS, &status);

    if (status == GL_FALSE)
    {
        glDeleteShader(shader);
        exit(1);
    }

    return shader;
}

- (NSString *)getVertexShaderString
{
    NSString *const kVertexShaderString = SHADER_STRING
    (
        attribute vec4 position;
        attribute vec4 inputTextureCoordinate;

        varying vec2 textureCoordinate;

        void main()
        {
            gl_Position = position;
            textureCoordinate = inputTextureCoordinate.xy;
        }
    );

    return kVertexShaderString;
}

- (NSString *)getFragmentShaderString
{
    NSString *const kFragmentShaderString = SHADER_STRING
    (
        varying highp vec2 textureCoordinate;

        uniform sampler2D videoFrame;

        void main()
        {
            gl_FragColor = texture2D(videoFrame, textureCoordinate);
        }
    );

    return kFragmentShaderString;
}

- (BOOL)loadShader
{
    // Vertex Shader
    NSString *vertexShaderString = [self getVertexShaderString];
    GLuint vertexShader = [self compileShader:vertexShaderString shardrType:GL_VERTEX_SHADER];

    // Fragment Shader
    NSString *fragmentShaderString = [self getFragmentShaderString];
    GLuint fragmentShader = [self compileShader:fragmentShaderString shardrType:GL_FRAGMENT_SHADER];

    // program
    GLuint programHandle = glCreateProgram();
    glAttachShader(programHandle, vertexShader);
    glAttachShader(programHandle, fragmentShader);

    glBindAttribLocation(programHandle, 0, "position");
    glBindAttribLocation(programHandle, 1, "inputTextureCoordinate");
    glLinkProgram(programHandle);

    GLint status = 0;
    glGetProgramiv(programHandle, GL_LINK_STATUS, &status);

    if (status == GL_FALSE)
    {
        if (vertexShader)
        {
            glDeleteShader(vertexShader);
            vertexShader = 0;
        }

        if (fragmentShader)
        {
            glDeleteShader(fragmentShader);
            fragmentShader = 0;
        }

        if (programHandle)
        {
            glDeleteProgram(programHandle);
            programHandle = 0;
        }

        return NO;
    }

    // uniform
    glUniform1i(glGetUniformLocation(programHandle, "videoFrame"), 0);
    glUseProgram(programHandle);

    if (vertexShader)
    {
        glDeleteShader(vertexShader);
        vertexShader = 0;
    }

    if (fragmentShader)
    {
        glDeleteShader(fragmentShader);
        fragmentShader = 0;
    }

    if (programHandle)
    {
        glDeleteProgram(programHandle);
        programHandle = 0;
    }

    // Texture
    GLuint texture = 0;
    glGenTextures(1, &texture);
    glBindTexture(GL_TEXTURE_2D, texture);

    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);

    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, texture);

    return YES;
}

- (void)drawFrame:(CVImageBufferRef)cameraFrame
{
    int bufferWidth = CVPixelBufferGetWidth(cameraFrame);
    int bufferHeight = CVPixelBufferGetHeight(cameraFrame);

    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, bufferWidth, bufferHeight, 0,
                 GL_BGRA, GL_UNSIGNED_BYTE, CVPixelBufferGetBaseAddress(cameraFrame));

    static const GLfloat squareVetrices[] = {
        -1.0f, -1.0f,
         1.0f, -1.0f,
        -1.0f,  1.0f,
         1.0f,  1.0f,
    };

    static const GLfloat textureVertices[] = {
         1.0f,  1.0f,
         1.0f,  0.0f,
         0.0f,  1.0f,
         0.0f,  0.0f
    };

    glViewport(0, 0, self.frame.size.width, self.frame.size.height);

    glVertexAttribPointer(0, 2, GL_FLOAT, 0, 0, squareVetrices);
    glEnableVertexAttribArray(0);

    glVertexAttribPointer(1, 2, GL_FLOAT, 0, 0, textureVertices);
    glEnableVertexAttribArray(1);

    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);

    [self.context presentRenderbuffer:GL_RENDERBUFFER];
}

- (UIImage *)convertUIImage
{
    int width = 0;
    int hgith = 0;

    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &width);
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &hgith);

    NSInteger myDateLength = width * hgith * 4;
    GLubyte *buffer = (GLubyte *)malloc(myDateLength);
    glReadPixels(0, 0, width, hgith, GL_RGBA, GL_UNSIGNED_BYTE, buffer);

    GLubyte *buffer2 = (GLubyte *)malloc(myDateLength);
    for (int y = 0; y < hgith; y++)
    {
        memcpy(&buffer2[((hgith -1) -y) * width *4], &buffer[y * 4 * width], sizeof(GLubyte) * width *4);
    }
    free(buffer);

    CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, buffer2, myDateLength, bufferFree);
    CGColorSpaceRef colorSpaceRef = CGColorSpaceCreateDeviceRGB();
    CGImageRef cgImage = CGImageCreate(width,
                                       hgith,
                                       8,
                                       32,
                                       4 * width,
                                       colorSpaceRef,
                                       kCGBitmapByteOrderDefault,
                                       provider,
                                       NULL,
                                       NO,
                                       kCGRenderingIntentDefault);

    UIImageOrientation imageOrientation = UIImageOrientationUp;

    switch([UIDevice currentDevice].orientation){
        case UIDeviceOrientationLandscapeLeft:
            imageOrientation = UIImageOrientationLeft;
            break;
        case UIDeviceOrientationLandscapeRight:
            imageOrientation = UIImageOrientationRight;
            break;
        case UIDeviceOrientationFaceDown:
            imageOrientation = UIImageOrientationDown;
            break;
        default:
            break;
    }

    UIImage *image = [UIImage imageWithCGImage:cgImage scale:1.0 orientation:imageOrientation];

    CGImageRelease(cgImage);
    CGColorSpaceRelease(colorSpaceRef);
    CGDataProviderRelease(provider);

    return image;
}

static void bufferFree(void *info, const void *data, size_t size)
{
    free((void *)data);
}

@end
