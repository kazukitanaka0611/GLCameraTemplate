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

@property (nonatomic, assign) GLint frameWidth;
@property (nonatomic, assign) GLint frameHeight;

@property (nonatomic, assign) GLubyte *rawImageData;
@property (nonatomic, assign) unsigned bufferRowBytes;

@end

@implementation OpenGLView

#pragma mark -
+ (Class)layerClass
{
    return [CAEAGLLayer class];
}

#pragma mark -
- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code

        if ([self respondsToSelector:@selector(setContentScaleFactor:)])
        {
            self.contentScaleFactor = [[UIScreen mainScreen] scale];
        }
        
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

#pragma mark -
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

    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &_frameWidth);
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &_frameHeight);

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

- (GLuint)compileShader:(NSString *)shaderString shaderType:(GLenum)shaderType
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

#pragma mark -
- (NSString *)getVertexShaderString
{
    NSString *const kVertexShaderString = SHADER_STRING
    (
        attribute vec4 position;
        attribute vec4 inputTextureCoordinate;

        varying vec2 textureCoordinate;

        uniform lowp float mirror;

        void main()
        {
            highp vec4 pos = position;
            pos.x *= mirror;
            
            gl_Position = pos;
            textureCoordinate = inputTextureCoordinate.xy;
        }
    );

    return kVertexShaderString;
}

#pragma mark -
- (NSString *)getFragmentShaderString
{
    NSString *const kFragmentShaderString = SHADER_STRING
    (
        varying highp vec2 textureCoordinate;

        uniform sampler2D inputImageTexture;

        void main()
        {
            gl_FragColor = texture2D(inputImageTexture, textureCoordinate);
        }
    );

    return kFragmentShaderString;
}

#pragma mark -
- (void)setUniform
{
    glUniform1i(glGetUniformLocation(_programHandle, "inputImageTexture"), 0);
}

#pragma mark -
- (BOOL)loadShader
{
    // Vertex Shader
    NSString *vertexShaderString = [self getVertexShaderString];
    GLuint vertexShader = [self compileShader:vertexShaderString shaderType:GL_VERTEX_SHADER];

    // Fragment Shader
    NSString *fragmentShaderString = [self getFragmentShaderString];
    GLuint fragmentShader = [self compileShader:fragmentShaderString shaderType:GL_FRAGMENT_SHADER];

    // program
    _programHandle = glCreateProgram();
    glAttachShader(_programHandle, vertexShader);
    glAttachShader(_programHandle, fragmentShader);

    glBindAttribLocation(_programHandle, 0, "position");
    glBindAttribLocation(_programHandle, 1, "inputTextureCoordinate");
    glLinkProgram(_programHandle);

    GLint status = 0;
    glGetProgramiv(_programHandle, GL_LINK_STATUS, &status);

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

        if (_programHandle)
        {
            glDeleteProgram(_programHandle);
            _programHandle = 0;
        }

        return NO;
    }

    // Texture
    GLuint texture = 0;
    glActiveTexture(GL_TEXTURE0);
    glGenTextures(1, &texture);
    glBindTexture(GL_TEXTURE_2D, texture);

    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);

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

    return YES;
}

#pragma mark -
- (BOOL)drawFrame:(CVImageBufferRef)cameraFrame
{
    BOOL success = FALSE;

    if (self.context)
    {
        int bufferWidth = CVPixelBufferGetWidth(cameraFrame);
        int bufferHeight = CVPixelBufferGetHeight(cameraFrame);

        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, bufferWidth, bufferHeight, 0,
                     GL_BGRA, GL_UNSIGNED_BYTE, CVPixelBufferGetBaseAddress(cameraFrame));

        static const GLfloat textureVertices[] = {
            1.0f,  1.0f,
            1.0f,  0.0f,
            0.0f,  1.0f,
            0.0f,  0.0f
        };

        success = [self render: textureVertices];
    }

    return success;
}

#pragma mark -
- (BOOL)drawImage:(UIImage *)image
{
    BOOL success = FALSE;

    if (self.context)
    {
        CGImageRef imageRef = image.CGImage;
        size_t imageWidth = CGImageGetWidth(imageRef);
        size_t imageHeight = CGImageGetHeight(imageRef);

        self.contentScaleFactor = image.scale;

        glClearColor(0.0, 0.0, 0.0, 0.0);
        glClear(GL_COLOR_BUFFER_BIT);

        size_t imageBytesPerRow = CGImageGetBytesPerRow(imageRef);
        size_t imageBitsPerComponent = CGImageGetBitsPerComponent(imageRef);
        CGColorSpaceRef imageColorSpace = CGImageGetColorSpace(imageRef);

        size_t imageTotalBytes = imageBytesPerRow * imageHeight;
        Byte* imageData = (Byte*)malloc(imageTotalBytes);

        memset(imageData, 0, imageTotalBytes);

        CGContextRef memContext = CGBitmapContextCreate(imageData,
                                                        imageWidth,
                                                        imageHeight,
                                                        imageBitsPerComponent,
                                                        imageBytesPerRow,
                                                        imageColorSpace,
                                                        kCGImageAlphaPremultipliedLast);

        CGContextDrawImage(memContext,
                           CGRectMake(0.0f, 0.0f, (CGFloat)imageWidth, (CGFloat)imageHeight), imageRef);

        CGContextRelease(memContext);
        
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, imageWidth, imageHeight, 0,
                     GL_RGBA, GL_UNSIGNED_BYTE, imageData);

        free(imageData);

        static const GLfloat textureVertices[] = {
            0.0f, 1.0f,
            1.0f, 1.0f,
            0.0f, 0.0f,
            1.0f, 0.0f
        };

        success = [self render:textureVertices];
    }

    return success;
}

#pragma mark -
- (BOOL)render:(const GLvoid*)textureVertices
{
    static const GLfloat squareVetrices[] = {
        -1.0f, -1.0f, 0.0f,
         1.0f, -1.0f, 0.0f,
        -1.0f,  1.0f, 0.0f,
         1.0f,  1.0f, 0.0f,
    };

    // uniform
    glUseProgram(_programHandle);
    glUniform1f(glGetUniformLocation(_programHandle, "mirror"), self.isMirrored ? -1.0f : 1.0f);
    [self setUniform];

    glViewport(0, 0, _frameWidth, _frameHeight);

    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 0, squareVetrices);
    glEnableVertexAttribArray(0);

    glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 0, textureVertices);
    glEnableVertexAttribArray(1);

    GLint status = 0;

    glValidateProgram(_programHandle);
    glGetProgramiv(_programHandle, GL_VALIDATE_STATUS, &status);

    if (status == GL_FALSE)
    {
        return NO;
    }

    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);

    glDisableVertexAttribArray(0);
    glDisableVertexAttribArray(1);

    return [self.context presentRenderbuffer:GL_RENDERBUFFER];
}

#pragma mark -
- (UIImage *)convertUIImage
{
    NSInteger myDateLength = _frameWidth * _frameHeight * 4;
    GLubyte *buffer = (GLubyte *)malloc(myDateLength);
    glReadPixels(0, 0, _frameWidth, _frameHeight, GL_RGBA, GL_UNSIGNED_BYTE, buffer);

    GLubyte *buffer2 = (GLubyte *)malloc(myDateLength);
    for (int y = 0; y < _frameHeight; y++)
    {
        memcpy(&buffer2[((_frameHeight -1) -y) * _frameWidth *4],
               &buffer[y * 4 * _frameWidth], sizeof(GLubyte) * _frameWidth *4);
    }
    free(buffer);

    CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, buffer2, myDateLength, bufferFree);
    CGColorSpaceRef colorSpaceRef = CGColorSpaceCreateDeviceRGB();
    CGImageRef cgImage = CGImageCreate(_frameWidth,
                                       _frameHeight,
                                       8,
                                       32,
                                       4 * _frameWidth,
                                       colorSpaceRef,
                                       kCGBitmapByteOrderDefault,
                                       provider,
                                       NULL,
                                       NO,
                                       kCGRenderingIntentDefault);

    UIImageOrientation imageOrientation = UIImageOrientationUp;

    switch([UIDevice currentDevice].orientation)
    {
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

#pragma mark -
static void bufferFree(void *info, const void *data, size_t size)
{
    free((void *)data);
}

#pragma mark -
- (void)startRecording
{
    // Raw Data
    NSInteger dataLength = (_frameWidth * _frameHeight) * 4;
    self.rawImageData = valloc(dataLength * sizeof(GLubyte));

    self.bufferRowBytes = ((unsigned)_frameWidth * 4 + 63) & ~63;
}

#pragma mark -
- (void)recordView:(CVImageBufferRef)pixelBuffer
{
    glReadPixels(0, 0, _frameWidth, _frameHeight, GL_BGRA_EXT, GL_UNSIGNED_BYTE, self.rawImageData);

    unsigned char* baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer);
    unsigned rowbytes = CVPixelBufferGetBytesPerRow(pixelBuffer);

    unsigned char* src;
    unsigned char* dst;

    for(unsigned int i = 0; i < _frameHeight; ++i)
    {
        src = self.rawImageData + self.bufferRowBytes * i;

        dst = baseAddress + rowbytes * ((unsigned)_frameHeight - 1 - i);

        memmove(dst, src, _frameWidth * 4);
    }
}

#pragma mark
- (void)stopRecording
{
    free(self.rawImageData);
    self.rawImageData = nil;
}

#pragma mark - dealloc
- (void)dealloc
{
    self.context = nil;

    if (_programHandle)
    {
        glDeleteProgram(_programHandle);
        _programHandle = 0;
    }
}

@end
