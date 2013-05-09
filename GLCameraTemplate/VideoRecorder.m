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

@end

@implementation VideoRecorder

#pragma mark -
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

    // Audio Writer
    NSDictionary *audioWriterSetting = @{
                                        AVFormatIDKey : @(kAudioFormatMPEG4AAC),
                                        AVNumberOfChannelsKey : @(1),
                                        AVSampleRateKey : @(preferredHardwareSampleRate),
                                        AVChannelLayoutKey : [NSData dataWithBytes:&acl length:sizeof(acl)],
                                        AVEncoderBitRateKey : @(64000)
                                      };
    
    self.audioWriter = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeAudio
                                                         outputSettings:audioWriterSetting];

    self.audioWriter.expectsMediaDataInRealTime = YES;
    
    if ([self.assertWriter canAddInput:self.audioWriter])
    {
        [self.assertWriter addInput:self.audioWriter];
    }
    
    // Video Writer
    NSDictionary *videoWriterSetting = @{
                                        AVVideoCodecKey : AVVideoCodecH264,
                                        AVVideoWidthKey : @(frame.size.width),
                                        AVVideoHeightKey : @(frame.size.height)
                                      };

    self.videoWriter = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo
                                                                outputSettings:videoWriterSetting];
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
    
    _adaptor = [[AVAssetWriterInputPixelBufferAdaptor alloc] initWithAssetWriterInput:self.videoWriter
                                                              sourcePixelBufferAttributes:pixelBufferAttributes];

    // Recoding
    _isRecording = YES;
    self.isFirstFrame = YES;

    // Start Writing
    [self.assertWriter startWriting];
}

#pragma mark -
- (NSURL *)stopRecording
{
    [self.audioWriter markAsFinished];
    [self.videoWriter markAsFinished];
    
#if __IPHONE_OS_VERSION_MIN_REQUIRED >= 60000
    [self.assertWriter finishWritingWithCompletionHandler:^{

        self.assertWriter = nil;
        self.audioWriter = nil;
        self.videoWriter = nil;
        _adaptor = nil;
    }];
#else
    [self.assertWriter finishWriting];
    self.assertWriter = nil;
    self.audioWriter = nil;
    self.videoWriter = nil;
    _adaptor = nil;
#endif

    _isRecording = NO;

    return self.movieURL;
}

#pragma mark -
- (void)writeSample:(CMSampleBufferRef)sampleBuffer
          mediaType:(NSString *)mediaType
        pixelBuffer:(CVPixelBufferRef)pixelBuffer
{
    if (self.assertWriter.status == AVAssetWriterStatusWriting)
    {
        if (mediaType == AVMediaTypeVideo)
        {
            // Video
            if (self.videoWriter.readyForMoreMediaData)
            {
                CMTime presentationTime = CMSampleBufferGetOutputPresentationTimeStamp(sampleBuffer);
                // Start
                if (self.isFirstFrame)
                {
                    [self.assertWriter startSessionAtSourceTime:presentationTime];
                    self.isFirstFrame = NO;
                }

                // Append
                BOOL append = [_adaptor appendPixelBuffer:pixelBuffer withPresentationTime:presentationTime];

                CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
                CVBufferRelease(pixelBuffer);

                if (!append)
                {
                    [self stopRecording];
                }
            }
        }
        else
        {
            // Audio
            if (self.audioWriter.readyForMoreMediaData)
            {
                [self.audioWriter appendSampleBuffer:sampleBuffer];
            }
        }
    }
}

#pragma mark - dealloc
- (void)dealloc
{
    self.movieURL = nil;
}

@end
