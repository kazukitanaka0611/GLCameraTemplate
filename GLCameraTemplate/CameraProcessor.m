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

@property (nonatomic, strong) AVCaptureDeviceInput *videoInput;

@end

@implementation CameraProcessor

#pragma mark -
- (id)initWithDelelgate:(id)delegate
{
    if (self = [super init])
    {
        self.delegate = delegate;

        // Public Property
        _deviceCount = [AVCaptureDevice devices].count;
        _hasFlash = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo].hasFlash;

        // AVCaptureSession
        _captureSession = [[AVCaptureSession alloc] init];

        // Audio Input
        AVCaptureDeviceInput *audioInput = [[AVCaptureDeviceInput alloc] initWithDevice:
                                            [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio]
                                                                                  error:nil];

        if ([_captureSession canAddInput:audioInput])
        {
            [_captureSession addInput:audioInput];
        }

        // Audio Output
        AVCaptureAudioDataOutput *audioOutput = [[AVCaptureAudioDataOutput alloc] init];

        // Audio Captuer Queue
        dispatch_queue_t audioCaptureQueue = dispatch_queue_create("Audio Capture Queue", DISPATCH_QUEUE_SERIAL);
        [audioOutput setSampleBufferDelegate:self queue:audioCaptureQueue];
#if __IPHONE_OS_VERSION_MIN_REQUIRED < 60000
        dispatch_release(audioCaptureQueue);
#endif
        if ([_captureSession canAddOutput:audioOutput])
        {
            [_captureSession addOutput:audioOutput];
        }

        // Video Input
        self.videoInput = [[AVCaptureDeviceInput alloc] initWithDevice:
                           [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo]
                                                                 error:nil];
        
        if ([_captureSession canAddInput:self.videoInput])
        {
            [_captureSession addInput:self.videoInput];
        }
        
        // Video Output
        AVCaptureVideoDataOutput *videoOutput = [[AVCaptureVideoDataOutput alloc] init];
        [videoOutput setAlwaysDiscardsLateVideoFrames:YES];
        videoOutput.videoSettings = @{(id)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32BGRA)};

        // Video Capture Queue
        dispatch_queue_t videoCaputerQueue = dispatch_queue_create("Video Capture Queue", DISPATCH_QUEUE_SERIAL);
        [videoOutput setSampleBufferDelegate:self queue:videoCaputerQueue];
#if __IPHONE_OS_VERSION_MIN_REQUIRED < 60000
        dispatch_release(videoCaputerQueue);
#endif
        if ([_captureSession canAddOutput:videoOutput])
        {
            [_captureSession addOutput:videoOutput];
        }

        [_captureSession setSessionPreset:AVCaptureSessionPresetMedium];

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

        if (![_captureSession isRunning])
        {
            [_captureSession startRunning];
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
        if (captureOutput == _captureSession.outputs[0])
        {
            mediaType = AVMediaTypeAudio;
        }

        if (mediaType == AVMediaTypeVideo)
        {
            [self makeOriginalCaptureImage:sampleBuffer];
        }
        
        if ([self.delegate respondsToSelector:@selector(processCameraFrame:mediaType:)])
        {
            [self.delegate processCameraFrame:sampleBuffer mediaType:mediaType];
        }

    });
}

#pragma mark -
- (void)makeOriginalCaptureImage:(CMSampleBufferRef)sampleBuffer
{
    CVImageBufferRef buffer = CMSampleBufferGetImageBuffer(sampleBuffer);

    CVPixelBufferLockBaseAddress(buffer, 0);

    uint8_t *base = CVPixelBufferGetBaseAddress(buffer);
    CGFloat width = CVPixelBufferGetWidth(buffer);
    CGFloat height = CVPixelBufferGetHeight(buffer);
    CGFloat bytesPerRow = CVPixelBufferGetBytesPerRow(buffer);

    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef cgContext = CGBitmapContextCreate(
                                                   base, width , height , 8,
                                                   bytesPerRow, colorSpace ,
                                                   kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    CGColorSpaceRelease(colorSpace);

    CGImageRef cgImage = CGBitmapContextCreateImage(cgContext);

    UIImageOrientation imageOrientation = UIImageOrientationRight;

    switch([UIDevice currentDevice].orientation)
    {
        case UIDeviceOrientationLandscapeLeft:
            imageOrientation = UIImageOrientationUp;
            break;
        case UIDeviceOrientationLandscapeRight:
            imageOrientation = UIImageOrientationDown;
            break;
        case UIDeviceOrientationFaceDown:
            imageOrientation = UIImageOrientationRight;
            break;
        default:
            break;
    }

    _originalCaptureImage = [UIImage imageWithCGImage:cgImage scale:(1.0 / [UIScreen mainScreen].scale)
                                          orientation:imageOrientation];

    CGImageRelease(cgImage);
    CGContextRelease(cgContext);

    CVPixelBufferUnlockBaseAddress(buffer, 0);
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
        [_captureSession beginConfiguration];
        [_captureSession removeInput:self.videoInput];
        self.videoInput = newInput;
        [_captureSession addInput:newInput];
        [_captureSession commitConfiguration];
    }
}

#pragma mark -
- (void)setFocus:(CGPoint)position
{
    [_captureSession beginConfiguration];

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
    
    [_captureSession commitConfiguration];
}

#pragma mark -
- (void)setTorch:(NSInteger)index
{
    [_captureSession beginConfiguration];
    
    AVCaptureDevice *device = self.videoInput.device;

	if ([device lockForConfiguration:nil])
    {
        [device setTorchMode:index];
        [device unlockForConfiguration];
    }

    [_captureSession commitConfiguration];
}

#pragma mark - dealloc
- (void)dealloc
{
    [_captureSession stopRunning];

    for (AVCaptureDeviceInput *input in _captureSession.inputs)
    {
        [_captureSession removeInput:input];
    }

    for (AVCaptureOutput *output in _captureSession.outputs)
    {
        [_captureSession removeOutput:output];
    }
    
    self.videoInput = nil;
    _captureSession = nil;

    self.delegate = nil;
}

@end
