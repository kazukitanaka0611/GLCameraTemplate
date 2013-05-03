//
//  AVCaptureCamera.m
//  GLCameraTemplate
//
//  Created by kazuki_tanaka on 2013/05/03.
//  Copyright (c) 2013年 kazukitanaka. All rights reserved.
//

#import "AVCaptureCamera.h"

#import <AVFoundation/AVFoundation.h>

@interface AVCaptureCamera()
    <AVCaptureVideoDataOutputSampleBufferDelegate>

@property (nonatomic, assign) id<AVCaptureCameraDelegate> delegate;
@property (nonatomic ,strong) AVCaptureSession *captureSession;

@end

@implementation AVCaptureCamera

- (id)initWithDelelgate:(id)aDelegate
{
    if (self = [super init])
    {
        self.delegate = aDelegate;
        
        self.captureSession = [[AVCaptureSession alloc] init];

        AVCaptureDeviceInput *videoInput = [[AVCaptureDeviceInput alloc] initWithDevice:
                                            [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo]
                                            error:nil];
        
        if ([self.captureSession canAddInput:videoInput])
        {
            [self.captureSession addInput:videoInput];
        }
        
        AVCaptureVideoDataOutput *videoOutput = [[AVCaptureVideoDataOutput alloc] init];
        [videoOutput setAlwaysDiscardsLateVideoFrames:YES];
        videoOutput.videoSettings = @{(id)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32BGRA)};
        [videoOutput setSampleBufferDelegate:self queue:dispatch_get_main_queue()];

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

- (void)captureOutput:(AVCaptureOutput *)captureOutput
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection
{
    CVImageBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);

    [self.delegate processCameraFrame:pixelBuffer];
}

@end
