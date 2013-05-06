//
//  AVCaptureCamera.m
//  GLCameraTemplate
//
//  Created by kazuki_tanaka on 2013/05/03.
//  Copyright (c) 2013年 kazukitanaka. All rights reserved.
//

#import "AVCaptureCamera.h"

@interface AVCaptureCamera()
    <AVCaptureVideoDataOutputSampleBufferDelegate,
     AVCaptureAudioDataOutputSampleBufferDelegate>

@property (nonatomic, assign) id<AVCaptureCameraDelegate> delegate;

@property (nonatomic ,strong) AVCaptureSession *captureSession;
@property (nonatomic, strong) AVCaptureVideoDataOutput *videoOutput;
@property (nonatomic, strong) AVCaptureAudioDataOutput *audioOutput;

@end

@implementation AVCaptureCamera

#pragma - mark
- (id)initWithDelelgate:(id)aDelegate
{
    if (self = [super init])
    {
        self.delegate = aDelegate;
        
        self.captureSession = [[AVCaptureSession alloc] init];

        // Audio Input
        AVCaptureDeviceInput *audioInput = [[AVCaptureDeviceInput alloc] initWithDevice:
                                            [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio]
                                                                                  error:nil];

        if ([self.captureSession canAddInput:audioInput])
        {
            [self.captureSession addInput:audioInput];
        }

        // Audio Output
        self.audioOutput = [[AVCaptureAudioDataOutput alloc] init];

        // Audio Captuer Queue
        dispatch_queue_t audioCaptureQueue = dispatch_queue_create("Audio Capture Queue", DISPATCH_QUEUE_SERIAL);
        [self.audioOutput setSampleBufferDelegate:self queue:audioCaptureQueue];
        dispatch_release(audioCaptureQueue);

        if ([self.captureSession canAddOutput:self.audioOutput])
        {
            [self.captureSession addOutput:self.audioOutput];
        }

        // Video Input
        AVCaptureDeviceInput *videoInput = [[AVCaptureDeviceInput alloc] initWithDevice:
                                            [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo]
                                                                                  error:nil];
        
        if ([self.captureSession canAddInput:videoInput])
        {
            [self.captureSession addInput:videoInput];
        }
        
        // Video Output
        self.videoOutput = [[AVCaptureVideoDataOutput alloc] init];
        [self.videoOutput setAlwaysDiscardsLateVideoFrames:YES];
        self.videoOutput.videoSettings = @{(id)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32BGRA)};

        // Video Capture Queue
        dispatch_queue_t videoCaputerQueue = dispatch_queue_create("Video Capture Queue", DISPATCH_QUEUE_SERIAL);
        [self.videoOutput setSampleBufferDelegate:self queue:videoCaputerQueue];
        dispatch_release(videoCaputerQueue);

        if ([self.captureSession canAddOutput:self.videoOutput])
        {
            [self.captureSession addOutput:self.videoOutput];
        }

        [self.captureSession setSessionPreset:AVCaptureSessionPresetMedium];

        if (![self.captureSession isRunning])
        {
            [self.captureSession startRunning];
        }
    }

    return self;
}

#pragma - mark
- (void)captureOutput:(AVCaptureOutput *)captureOutput
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection
{
    dispatch_sync(dispatch_get_main_queue(), ^{

        if(captureOutput == self.videoOutput)
        {
            [self.delegate processCameraFrame:sampleBuffer];
        }

        if (captureOutput == self.audioOutput)
        {
           
        }
    });
}

@end
