//
//  OpenGLView.h
//  GLCameraTemplate
//
//  Created by kazuki_tanaka on 2013/05/01.
//  Copyright (c) 2013年 kazukitanaka. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface OpenGLView : UIView

#define STRINGIZE(x) #x
#define STRINGIZE2(x) STRINGIZE(x)
#define SHADER_STRING(text) @ STRINGIZE2(text)

- (BOOL)drawFrame:(CVImageBufferRef)cameraFrame;
- (UIImage *)convertUIImage;
- (void)startRecording;
- (void)recordView:(CVPixelBufferRef)pixelBuffer;
- (void)stopRecording;

- (NSString *)getVertexShaderString;
- (NSString *)getFragmentShaderString;
- (void)setUniform;

@property (nonatomic, assign) BOOL isMirrored;

@end
