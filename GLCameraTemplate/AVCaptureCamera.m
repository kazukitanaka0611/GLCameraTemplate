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
        
        // Video Input
        AVCaptureDeviceInput *videoInput = [[AVCaptureDeviceInput alloc] initWithDevice:
                                            [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo]
                                                                                  error:nil];
        
        if ([self.captureSession canAddInput:videoInput])
        {
            [self.captureSession addInput:videoInput];
        }

        // Video Output
        AVCaptureVideoDataOutput *videoOutput = [[AVCaptureVideoDataOutput alloc] init];
        [videoOutput setAlwaysDiscardsLateVideoFrames:YES];
        videoOutput.videoSettings = @{(id)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32BGRA)};

        // Video Capture Queue
        dispatch_queue_t videoCaputerQueue = dispatch_queue_create("Video Capture Queue", DISPATCH_QUEUE_SERIAL);
        [videoOutput setSampleBufferDelegate:self queue:videoCaputerQueue];
        dispatch_release(videoCaputerQueue);

        if ([self.captureSession canAddOutput:videoOutput])
        {
            [self.captureSession addOutput:videoOutput];
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
        [self.delegate processCameraFrame:sampleBuffer];
    });
}

@end
