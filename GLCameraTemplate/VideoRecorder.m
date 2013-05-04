//
//  AVCameraRecorder.m
//  GLCameraTemplate
//
//  Created by kazuki_tanaka on 2013/05/04.
//  Copyright (c) 2013年 kazukitanaka. All rights reserved.
//

#import "VideoRecorder.h"

@interface VideoRecorder()

@property (nonatomic, assign) BOOL isFirstFrame;
@property (nonatomic, strong) NSURL *movieURL;

@property (nonatomic, strong) AVAssetWriter *assertWriter;
@property (nonatomic, strong) AVAssetWriterInput *assertWriterInput;
@property (nonatomic, strong) AVAssetWriterInputPixelBufferAdaptor *adaptor;

@property (nonatomic, assign) GLubyte *rawImageData;

@property (nonatomic, assign) unsigned bufferRowBytes;

@end

@implementation VideoRecorder

#pragma - mark
- (void)startRecording:(CGRect)frame
{
    // Movie URL
    self.movieURL = [NSURL fileURLWithPath:[NSString stringWithFormat:@"%@,%@",NSTemporaryDirectory(), @"sample.mov"]];

    NSFileManager *fileManger = [NSFileManager defaultManager];
    NSString *filePath = self.movieURL.path;

    if ([fileManger fileExistsAtPath:filePath])
    {
        [fileManger removeItemAtPath:filePath error:nil];
    }

    // AssertWriter
    self.assertWriter = [[AVAssetWriter alloc] initWithURL:self.movieURL
                                                  fileType:AVFileTypeQuickTimeMovie
                                                     error:nil];
    // AssertWriterInput
    NSDictionary *assertWriterInputSetting = @{
                                                AVVideoCodecKey : AVVideoCodecH264,
                                                AVVideoWidthKey : @(frame.size.width),
                                                AVVideoHeightKey : @(frame.size.height)
                                              };
    
    self.assertWriterInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo
                                                                outputSettings:assertWriterInputSetting];
    self.assertWriterInput.expectsMediaDataInRealTime = NO;

    if ([self.assertWriter canAddInput:self.assertWriterInput])
    {
        [self.assertWriter addInput:self.assertWriterInput];
    }

    // AVAssetWriterInputPixelBufferAdaptor
    NSDictionary *pixelBufferAttributes = @{
                                                (NSString *)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32BGRA),
                                                (NSString *)kCVPixelBufferWidthKey : @(frame.size.width),
                                                (NSString *)kCVPixelBufferHeightKey : @(frame.size.height),
                                                (NSString *)kCVPixelBufferBytesPerRowAlignmentKey : @(frame.size.width * 4)
                                            };
    
    self.adaptor = [[AVAssetWriterInputPixelBufferAdaptor alloc] initWithAssetWriterInput:self.assertWriterInput
                                                              sourcePixelBufferAttributes:pixelBufferAttributes];

    // Start Writing
    [self.assertWriter startWriting];

    NSInteger dataLength = (frame.size.width * frame.size.height) * 4;
    _rawImageData = valloc(dataLength * sizeof(GLubyte));

    _bufferRowBytes = ((unsigned)frame.size.width * 4 + 63) & ~63;
    
    // Recoding
    _isRecording = YES;
    self.isFirstFrame = YES;
}

#pragma - mark
- (NSURL *)stopRecording
{
#if __IPHONE_OS_VERSION_MIN_REQUIRED >= 60000
    [self.assertWriter finishWritingWithCompletionHandler:^{

        self.assertWriter = nil;
        self.assertWriterInput = nil;
        self.adaptor = nil;
    }];
#else
    [self.assertWriter finishWriting];
    self.assertWriter = nil;
    self.assertWriterInput = nil;
    self.adaptor = nil;
#endif

    _isRecording = NO;

    free(_rawImageData);
    _rawImageData = nil;
    
    return self.movieURL;
}

#pragma - mark
- (void)writeSampleAtTime:(CMTime)presentationTime frame:(CGRect)frame
{
    if (self.assertWriterInput.readyForMoreMediaData)
    {
        // Start
        if (self.isFirstFrame)
        {
            [self.assertWriter startSessionAtSourceTime:presentationTime];
            self.isFirstFrame = NO;
        }

        glReadPixels(0, 0, frame.size.width, frame.size.height, GL_BGRA_EXT, GL_UNSIGNED_BYTE, _rawImageData);
        
        CVPixelBufferRef pixelBuffer = NULL;
        CVReturn cvErr = CVPixelBufferPoolCreatePixelBuffer(nil, [self.adaptor pixelBufferPool], &pixelBuffer);

        CVPixelBufferLockBaseAddress(pixelBuffer, 0);

        if (cvErr != kCVReturnSuccess)
        {
            CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
            CVBufferRelease(pixelBuffer);
            exit(1);
        }

        unsigned char* baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer);
        unsigned rowbytes = CVPixelBufferGetBytesPerRow(pixelBuffer);

        unsigned char* src;
        unsigned char* dst;

        for(unsigned int i = 0; i < frame.size.height; ++i) {

            src = _rawImageData + _bufferRowBytes * i;

            dst = baseAddress + rowbytes * ((unsigned)frame.size.height - 1 - i);

            memmove(dst, src, frame.size.width * 4);
        }

        // Append
        BOOL append = [self.adaptor appendPixelBuffer:pixelBuffer withPresentationTime:presentationTime];

        CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
        CVBufferRelease(pixelBuffer);

        if (!append)
        {
            [self stopRecording];
        }
    }
}

@end
