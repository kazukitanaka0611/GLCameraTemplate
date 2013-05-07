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
@property (nonatomic, strong) AVAssetWriterInput *audioWriter;
@property (nonatomic, strong) AVAssetWriterInput *videoWriter;
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
    // Audio Input
    CGFloat preferredHardwareSampleRate = [[AVAudioSession sharedInstance] currentHardwareSampleRate];

    AudioChannelLayout acl;
    bzero(&acl, sizeof(acl));
    acl.mChannelLayoutTag = kAudioChannelLayoutTag_Mono;

    NSDictionary *audioInputSetting = @{
                                        AVFormatIDKey : @(kAudioFormatMPEG4AAC),
                                        AVNumberOfChannelsKey : @(1),
                                        AVSampleRateKey : @(preferredHardwareSampleRate),
                                        AVChannelLayoutKey : [NSData dataWithBytes:&acl length:sizeof(acl)],
                                        AVEncoderBitRateKey : @(64000)
                                      };
    
    self.audioWriter = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeAudio
                                                         outputSettings:audioInputSetting];

    self.audioWriter.expectsMediaDataInRealTime = YES;
    
    if ([self.assertWriter canAddInput:self.audioWriter])
    {
        [self.assertWriter addInput:self.audioWriter];
    }
    
    // Video Input
    NSDictionary *videoInputSetting = @{
                                        AVVideoCodecKey : AVVideoCodecH264,
                                        AVVideoWidthKey : @(frame.size.width),
                                        AVVideoHeightKey : @(frame.size.height)
                                      };

    self.videoWriter = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo
                                                                outputSettings:videoInputSetting];
    self.videoWriter.expectsMediaDataInRealTime = YES;

    if ([self.assertWriter canAddInput:self.videoWriter])
    {
        [self.assertWriter addInput:self.videoWriter];
    }

    // AVAssetWriterInputPixelBufferAdaptor
    NSDictionary *pixelBufferAttributes = @{
                                                (NSString *)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32BGRA),
                                                (NSString *)kCVPixelBufferWidthKey : @(frame.size.width),
                                                (NSString *)kCVPixelBufferHeightKey : @(frame.size.height),
                                                (NSString *)kCVPixelBufferBytesPerRowAlignmentKey : @(frame.size.width * 4)
                                            };
    
    self.adaptor = [[AVAssetWriterInputPixelBufferAdaptor alloc] initWithAssetWriterInput:self.videoWriter
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
    [self.audioWriter markAsFinished];
    [self.videoWriter markAsFinished];
    
#if __IPHONE_OS_VERSION_MIN_REQUIRED <= 60000
    [self.assertWriter finishWritingWithCompletionHandler:^{

        self.assertWriter = nil;
        self.audioWriter = nil;
        self.videoWriter = nil;
        self.adaptor = nil;
    }];
#else
    [self.assertWriter finishWriting];
    self.assertWriter = nil;
    self.audioWriter = nil;
    self.videoWriter = nil;
    self.adaptor = nil;
#endif

    _isRecording = NO;

    free(_rawImageData);
    _rawImageData = nil;
    
    return self.movieURL;
}

#pragma - mark
- (void)writeSample:(CMSampleBufferRef)sampleBuffer frame:(CGRect)frame
{
    if (self.assertWriter.status == AVAssetWriterStatusWriting)
    {
        if (self.videoWriter.readyForMoreMediaData)
        {
            CMTime presentationTime = CMSampleBufferGetOutputPresentationTimeStamp(sampleBuffer);
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
}

- (void)writeAudioSample:(CMSampleBufferRef)sampleBuffer
{
    if (self.audioWriter.readyForMoreMediaData)
    {
        [self.audioWriter appendSampleBuffer:sampleBuffer];
    }
}

@end
