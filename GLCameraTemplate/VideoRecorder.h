//
//  AVCameraRecorder.h
//  GLCameraTemplate
//
//  Created by kazuki_tanaka on 2013/05/04.
//  Copyright (c) 2013年 kazukitanaka. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <AVFoundation/AVFoundation.h>

@interface VideoRecorder : NSObject

@property (nonatomic, readonly) BOOL isRecording;

- (void)startRecording:(CGRect)frame;
- (NSURL *)stopRecording;
- (void)writeSample:(CMSampleBufferRef)sampleBuffer
          mediaType:(NSString *)mediaType
        pixelBuffer:(CVPixelBufferRef)pixelBuffer;

@property (nonatomic, readonly) AVAssetWriterInputPixelBufferAdaptor *adaptor;

@end
