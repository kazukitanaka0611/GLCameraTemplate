//
//  CameraProcessor.m
//  GLCameraTemplate
//
//  Created by kazuki_tanaka on 2013/05/03.
//  Copyright (c) 2013年 kazukitanaka. All rights reserved.
//

#import "CameraProcessor.h"

@interface CameraProcessor()
    <AVCaptureVideoDataOutputSampleBufferDelegate,
     AVCaptureAudioDataOutputSampleBufferDelegate>

@property (nonatomic, assign) id<CameraProcessorDelegate> delegate;

@property (nonatomic ,strong) AVCaptureSession *captureSession;
@property (nonatomic, strong) AVCaptureDeviceInput *videoInput;

@end

@implementation CameraProcessor

#pragma mark -
- (id)initWithDelelgate:(id)delegate view:(UIView *)view
{
    if (self = [super init])
    {
        self.delegate = delegate;

        // Public Property
        _deviceCount = [AVCaptureDevice devices].count;
        _hasFlash = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo].hasFlash;

        // AVCaptureSession
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
        AVCaptureAudioDataOutput *audioOutput = [[AVCaptureAudioDataOutput alloc] init];

        // Audio Captuer Queue
        dispatch_queue_t audioCaptureQueue = dispatch_queue_create("Audio Capture Queue", DISPATCH_QUEUE_SERIAL);
        [audioOutput setSampleBufferDelegate:self queue:audioCaptureQueue];
        //dispatch_release(audioCaptureQueue);

        if ([self.captureSession canAddOutput:audioOutput])
        {
            [self.captureSession addOutput:audioOutput];
        }

        // Video Input
        self.videoInput = [[AVCaptureDeviceInput alloc] initWithDevice:
                           [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo]
                                                                 error:nil];
        
        if ([self.captureSession canAddInput:self.videoInput])
        {
            [self.captureSession addInput:self.videoInput];
        }
        
        // Video Output
        AVCaptureVideoDataOutput *videoOutput = [[AVCaptureVideoDataOutput alloc] init];
        [videoOutput setAlwaysDiscardsLateVideoFrames:YES];
        videoOutput.videoSettings = @{(id)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32BGRA)};

        // Video Capture Queue
        dispatch_queue_t videoCaputerQueue = dispatch_queue_create("Video Capture Queue", DISPATCH_QUEUE_SERIAL);
        [videoOutput setSampleBufferDelegate:self queue:videoCaputerQueue];
        //dispatch_release(videoCaputerQueue);

        if ([self.captureSession canAddOutput:videoOutput])
        {
            [self.captureSession addOutput:videoOutput];
        }

        [self.captureSession setSessionPreset:AVCaptureSessionPresetMedium];

        // Configuration
        if ([self.videoInput.device lockForConfiguration:nil])
        {
            // Foucus
            if ([self.videoInput.device isFocusPointOfInterestSupported]
            &&  [self.videoInput.device isFocusModeSupported:AVCaptureFocusModeAutoFocus])
            {
                self.videoInput.device.focusMode = AVCaptureFocusModeAutoFocus;
            }

            // Exposure
            if ([self.videoInput.device isExposurePointOfInterestSupported]
            && [self.videoInput.device isExposureModeSupported:AVCaptureExposureModeAutoExpose])
            {
                self.videoInput.device.exposureMode = AVCaptureExposureModeAutoExpose;
            }

            // Flash
            if ([self.videoInput.device isFocusModeSupported:AVCaptureFlashModeAuto])
            {
                self.videoInput.device.focusMode = AVCaptureFlashModeAuto;
            }

            // WhiteBalance
            if ([self.videoInput.device isWhiteBalanceModeSupported:AVCaptureWhiteBalanceModeAutoWhiteBalance])
            {
                self.videoInput.device.whiteBalanceMode = AVCaptureWhiteBalanceModeAutoWhiteBalance;
            }

            // Tourch
            if ([self.videoInput.device isTorchModeSupported:AVCaptureTorchModeAuto])
            {
                self.videoInput.device.torchMode = AVCaptureTorchModeAuto;
            }

            [self.videoInput.device unlockForConfiguration];
        }

        // AVCaptureVideoPreviewLayer
        AVCaptureVideoPreviewLayer *previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.captureSession];
        [previewLayer setBackgroundColor:[[UIColor blackColor] CGColor]];
        [previewLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill];

        // RootLayer
        CALayer *rootLayer = [view layer];
        [rootLayer setMasksToBounds:YES];
        [previewLayer setFrame:[rootLayer bounds]];
        [rootLayer addSublayer:previewLayer];

        if (![self.captureSession isRunning])
        {
            [self.captureSession startRunning];
        }
    }

    return self;
}

#pragma mark -
- (void)captureOutput:(AVCaptureOutput *)captureOutput
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection
{
    dispatch_sync(dispatch_get_main_queue(), ^{

        NSString *mediaType = AVMediaTypeVideo;

        // Audio Output
        if (captureOutput == self.captureSession.outputs[0])
        {
            mediaType = AVMediaTypeAudio;
        }

        if ([self.delegate respondsToSelector:@selector(processCameraFrame:mediaType:)])
        {
            [self.delegate processCameraFrame:sampleBuffer mediaType:mediaType];
        }

    });
}

#pragma mark -
- (void)switchCamera
{
    _isFrontCamera = NO;
    
    AVCaptureDevicePosition setPosition = AVCaptureDevicePositionBack;

    if (self.videoInput.device.position == AVCaptureDevicePositionBack)
    {
        setPosition = AVCaptureDevicePositionFront;
        _isFrontCamera = YES;
    }

    AVCaptureDeviceInput *newInput = nil;
    for (AVCaptureDevice *device in [AVCaptureDevice devices])
    {
        if ([device position] == setPosition)
        {
            newInput = [[AVCaptureDeviceInput alloc]initWithDevice:device error:nil];
        }
    }

    if (newInput != nil)
    {
        [self.captureSession beginConfiguration];
        [self.captureSession removeInput:self.videoInput];
        self.videoInput = newInput;
        [self.captureSession addInput:newInput];
        [self.captureSession commitConfiguration];
    }
}

#pragma mark -
- (void)setFocus:(CGPoint)position
{
    [self.captureSession beginConfiguration];

    AVCaptureDevice *device = self.videoInput.device;

    // Focus set
    if (device.isFocusPointOfInterestSupported
    && [device isFocusModeSupported:AVCaptureFocusModeAutoFocus]
    ) {
        if ([device lockForConfiguration:nil])
        {
            // !!!: This is not work
            //device.focusPointOfInterest = position;
            device.focusMode = AVCaptureFocusModeAutoFocus;

            [device unlockForConfiguration];
        }
    }

    // Expouse Set
    if (device.isExposurePointOfInterestSupported
    && [device isExposureModeSupported:AVCaptureExposureModeAutoExpose])
    {
        if ([device lockForConfiguration:nil])
        {
            device.exposurePointOfInterest = position;
            device.exposureMode = AVCaptureExposureModeAutoExpose;

            [device unlockForConfiguration];
        }
    }
    
    [self.captureSession commitConfiguration];
}

#pragma mark -
- (void)setTorch:(NSInteger)index
{
    [self.captureSession beginConfiguration];
    
    AVCaptureDevice *device = self.videoInput.device;

	if ([device lockForConfiguration:nil])
    {
        [device setTorchMode:index];
        [device unlockForConfiguration];
    }

    [self.captureSession commitConfiguration];
}

#pragma mark - dealloc
- (void)dealloc
{
    [self.captureSession stopRunning];

    for (AVCaptureDeviceInput *input in self.captureSession.inputs)
    {
        [self.captureSession removeInput:input];
    }

    for (AVCaptureOutput *output in self.captureSession.outputs)
    {
        [self.captureSession removeOutput:output];
    }
    
    self.videoInput = nil;
    self.captureSession = nil;

    self.delegate = nil;
}

@end
