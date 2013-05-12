//
//  GLCameraViewController.m
//  GLCameraTemplate
//
//  Created by kazuki_tanaka on 2013/05/01.
//  Copyright (c) 2013年 kazukitanaka. All rights reserved.
//

#import "GLCameraViewController.h"

#import <AudioToolbox/AudioToolbox.h>
#import <AssetsLibrary/AssetsLibrary.h>

#import "CameraProcessor.h"
#import "VideoRecorder.h"

#import "CameraFlashButton.h"
#import "PhotoPreviewViewController.h"
#import "VideoPreviewViewController.h"

@interface GLCameraViewController ()

@property (nonatomic, strong) OpenGLView *glView;
@property (nonatomic, strong) CameraProcessor *cameraProcessor;
@property (nonatomic, strong) VideoRecorder *videoRecorder;

@property (nonatomic, strong) UIButton *switchCameraButton;
@property (nonatomic, strong) CameraFlashButton *flashButton;
@property (nonatomic, strong) UISlider *slider;
@property (nonatomic, strong) UIImageView *shutterImageView;
@property (nonatomic, strong) UIImageView *focusImageView;
@property (nonatomic, strong) UILabel *timerLabel;

@property (nonatomic, assign) BOOL isVideo;
@property (nonatomic, assign) CGFloat displayTime;
@property (nonatomic, assign) NSTimer *timer;

@end

@implementation GLCameraViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.

    // OpenGL View
    self.glView = [self createOpenGLView];
    [self.view addSubview:self.glView];

    // Camera
    self.cameraProcessor = [[CameraProcessor alloc] initWithDelelgate:self];

    // Video Recorder
    self.videoRecorder = [[VideoRecorder alloc] init];
    
    // Camera Switch Button
    self.switchCameraButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.switchCameraButton.frame = CGRectMake(250.0f, 10.0f, 60.0f, 32.0f);
    self.switchCameraButton.backgroundColor = [UIColor clearColor];
    [self.switchCameraButton setImage:[UIImage imageNamed:@"Toggle"] forState:UIControlStateNormal];
    self.switchCameraButton.layer.backgroundColor = [[UIColor colorWithWhite:1.0f alpha:0.2f] CGColor];
    self.switchCameraButton.layer.borderWidth = 1.0f;
    self.switchCameraButton.layer.cornerRadius = 15.0f;
    [self.switchCameraButton addTarget:self
                           action:@selector(switchCameraButtonClick:)
                 forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.switchCameraButton];

    if (1 == self.cameraProcessor.deviceCount)
    {
        self.switchCameraButton.hidden = YES;
    }

    // Camera Flash button
    self.flashButton = [[CameraFlashButton alloc] initWithPosition:CGPointMake(10, 10)
                                                            tiltle:@"flash"
                                                       buttonNames:@[@"OFF", @"ON", @"Auto"]
                                                        selectItem:2];
    [self.flashButton addTarget:self action:@selector(setFlashLight:) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:self.flashButton];
    
    if (!self.cameraProcessor.hasFlash)
    {
        self.flashButton.hidden = YES;
    }
    
    // UIToolbar
    UIToolbar *toolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, self.view.frame.size.height - 44.0f,
                                                                     self.view.frame.size.width, 44.0f)];
    [self.view addSubview:toolbar];

    // UISlider
    self.slider = [[UISlider alloc] initWithFrame:CGRectMake(self.view.frame.size.width - 70.0f,
                                                             toolbar.frame.origin.y + 20.0f, 60.0f, 1.0f)];
    [self.slider setThumbImage:[UIImage imageNamed:@"Handle"] forState:UIControlStateNormal];
    self.slider.maximumValue = 1;
    self.slider.minimumValue = 0;
    self.slider.value = 0;
    [self.slider addTarget:self action:@selector(sliderChange:) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:self.slider];

    // CameraImageView
    UIImageView *cameraImageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"Camera"]];
    cameraImageView.frame = CGRectMake(self.slider.frame.origin.x,
                                       toolbar.frame.origin.y + 1.0f, 30.0f, 25.0f);
    [self.view addSubview:cameraImageView];

    // VideoImageView
    UIImageView *videoImageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"Video"]];
    videoImageView.frame = CGRectMake(self.slider.frame.origin.x + self.slider.frame.size.width - 25.0f,
                                       toolbar.frame.origin.y + 1.0f, 30.0f, 25.0f);
    [self.view addSubview:videoImageView];

    // ShutterImageView
    self.shutterImageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"CameraLarge"]];
    self.shutterImageView.frame = CGRectMake(self.view.frame.size.width / 2,
                                             self.view.frame.size.height - 44.0f, 30.0f, 20.0f);
    self.shutterImageView.center = toolbar.center;
    [self.view addSubview:self.shutterImageView];

    UIButton *shutterButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    shutterButton.frame = CGRectMake(0, 0, 100, 35);
    [shutterButton addTarget:self action:@selector(shutterButtonClick:) forControlEvents:UIControlEventTouchUpInside];
    
    // Shutter Button
    UIBarButtonItem *shutterButtonItem = [[UIBarButtonItem alloc] initWithCustomView:shutterButton];

    // Space
    UIBarButtonItem *spaceButtonItem = [[UIBarButtonItem alloc]
                                        initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                        target:nil action:nil];
    toolbar.items = @[ spaceButtonItem, shutterButtonItem, spaceButtonItem ];

    // TimerLabel
    self.timerLabel = [[UILabel alloc] initWithFrame:CGRectMake(self.view.frame.size.width - 75.0f, 10.0f, 65.0f, 32.0f)];
    self.timerLabel.backgroundColor = [UIColor clearColor];
    self.timerLabel.textColor = [UIColor whiteColor];
#if __IPHONE_OS_VERSION_MIN_REQUIRED >= 60000
    self.timerLabel.textAlignment = NSTextAlignmentCenter;
#else
    self.timerLabel.textAlignment = UITextAlignmentCenter;
#endif
    self.timerLabel.layer.backgroundColor = [[UIColor colorWithWhite:1.0f alpha:0.2f] CGColor];
    self.timerLabel.layer.borderWidth = 1.0f;
    self.timerLabel.layer.cornerRadius = 5.0f;
    self.timerLabel.hidden = YES;
    [self.view addSubview:self.timerLabel];

    // FocusImageViw
    self.focusImageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"Focus"]];
    self.focusImageView.frame = CGRectMake(0, 0, 100, 100);
    self.focusImageView.alpha = 0;
    [self.view addSubview:self.focusImageView];
    
    // TapGestureRecognizer
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapGestureHandler:)];
    [self.glView addGestureRecognizer:tapGesture];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark -
- (OpenGLView *)createOpenGLView
{
    return [[OpenGLView alloc] initWithFrame:self.view.bounds];
}

#pragma mark -
- (void)processCameraFrame:(CMSampleBufferRef)sampleBuffer mediaType:(NSString *)mediaType
{
    if (self.videoRecorder.isRecording)
    {
        CVPixelBufferRef pixelBuffer = NULL;
        CVReturn cvErr = CVPixelBufferPoolCreatePixelBuffer(nil, self.videoRecorder.adaptor.pixelBufferPool, &pixelBuffer);

        CVPixelBufferLockBaseAddress(pixelBuffer, 0);

        if (cvErr != kCVReturnSuccess)
        {
            CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
            CVBufferRelease(pixelBuffer);
            exit(1);
        }

        [self.glView recordView:pixelBuffer];
        
        [self.videoRecorder writeSample:sampleBuffer mediaType:mediaType pixelBuffer:pixelBuffer];

        CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
        CVBufferRelease(pixelBuffer);
    }

    if (mediaType == AVMediaTypeVideo)
    {
        CVImageBufferRef cameraFrame = CMSampleBufferGetImageBuffer(sampleBuffer);

        CVPixelBufferLockBaseAddress(cameraFrame, 0);

        [self.glView drawFrame:cameraFrame];

        CVPixelBufferUnlockBaseAddress(cameraFrame, 0);
    }
}

#pragma mark =
- (void)shutterButtonClick:(UIButton *)button
{
    if (!self.isVideo)
    {
        AudioServicesPlaySystemSound(1108);

        __block UIImage *saveImage = [self.glView convertUIImage];

        ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
        [library writeImageToSavedPhotosAlbum:saveImage.CGImage
                                   orientation:(ALAssetOrientation)saveImage.imageOrientation
                               completionBlock:^(NSURL *assetURL, NSError *error){

                                   PhotoPreviewViewController *controller = [[PhotoPreviewViewController alloc]initWithImage:saveImage];
                                   [self presentViewController:controller animated:YES completion:NULL];
                               }];
    }
    else
    {
        if (!self.videoRecorder.isRecording)
        {
            self.displayTime = 0;
            self.timerLabel.text = [NSString stringWithFormat:@"%02d:%02d",0, 0];
            self.timerLabel.hidden = NO;
            self.shutterImageView.image = [UIImage imageNamed:@"RecordOn"];
            self.slider.enabled = NO;
            
            [self.glView startRecording];

            self.timer = [NSTimer scheduledTimerWithTimeInterval:1.0f
                                                          target:self
                                                        selector:@selector(updateLabel:)
                                                        userInfo:nil
                                                         repeats:YES];

            if (self.cameraProcessor.hasFlash)
            {
                self.flashButton.hidden = YES;
            }

            if (1 < self.cameraProcessor.deviceCount)
            {
                self.switchCameraButton.hidden = YES;
            }

            AudioServicesAddSystemSoundCompletion(1117, NULL, NULL, endSound, (__bridge void*)self);
            AudioServicesPlaySystemSound(1117);
        }
        else
        {
            self.displayTime = 0;
            self.timerLabel.hidden = YES;
            self.shutterImageView.image = [UIImage imageNamed:@"RecordOff"];
            self.slider.enabled = YES;
            
            [self.timer invalidate];
            
            AudioServicesPlaySystemSound(1118);

            if (self.cameraProcessor.hasFlash
            && !self.cameraProcessor.isFrontCamera)
            {
                self.flashButton.hidden = NO;
            }

            if (1 < self.cameraProcessor.deviceCount)
            {
                self.switchCameraButton.hidden = NO;
            }

            // Stop Record
            __block NSURL *movieURL = [self.videoRecorder stopRecording];

            [self.glView stopRecording];

            ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
            [library writeVideoAtPathToSavedPhotosAlbum:movieURL
                                        completionBlock:^(NSURL *assetURL, NSError *error){

                                            VideoPreviewViewController *controller = [[VideoPreviewViewController alloc] init];
                                            controller.videoPath = movieURL.path;
                                            [self presentViewController:controller animated:YES completion:NULL];
                                        }];
        }

    }
}

#pragma mark -
static void endSound (SystemSoundID soundID, void *myself)
{
    [((__bridge GLCameraViewController *)myself).videoRecorder
     startRecording:((__bridge GLCameraViewController *)myself).glView.bounds];
    
    AudioServicesRemoveSystemSoundCompletion (soundID);
}

#pragma mark -
- (void)updateLabel:(NSTimer *)timer
{
    self.displayTime += (self.timerLabel.text.floatValue + timer.timeInterval);

    self.timerLabel.text = [NSString stringWithFormat:@"%02d:%02d",
                            (NSInteger)self.displayTime / 60,  (NSInteger)self.displayTime % 60];
}

#pragma mark -
- (void)switchCameraButtonClick:(UIButton *)button
{
    [self.cameraProcessor switchCamera];

    [self focusAnimation:self.glView.center];
    
    [self.cameraProcessor setFocus:self.glView.center];
    
    if (self.cameraProcessor.isFrontCamera)
    {
        self.flashButton.hidden = YES;
        self.glView.isMirrored = YES;
    }
    else
    {
        self.flashButton.hidden = NO;
        self.glView.isMirrored = NO;
    }
}

#pragma mark -
- (void)sliderChange:(UISlider *)slider
{
    if (slider.value < 0.5)
    {
        slider.value = 0;
        self.isVideo = NO;
        self.shutterImageView.frame = CGRectMake(145.0f,
                                                 self.view.frame.size.height - 33.35f, 30.0f, 20.0f);
        self.shutterImageView.image = [UIImage imageNamed:@"CameraLarge"];
    }
    else
    {
        slider.value = 1;
        self.isVideo = YES;
        self.shutterImageView.frame = CGRectMake(142.0f,
                                                 self.view.frame.size.height - 38.0f, 40.0f, 30.0f);
        self.shutterImageView.image = [UIImage imageNamed:@"RecordOff"];
    }
}

#pragma mark -
- (void)setFlashLight:(id)sender
{
    [self.cameraProcessor setTorch:[((CameraFlashButton *)sender) selectedItem]];
}

#pragma mark -
- (void)tapGestureHandler:(UITapGestureRecognizer *)recogniser
{
    CGPoint point = [recogniser locationInView:self.glView];

    [self focusAnimation:point];

    [self.cameraProcessor setFocus:point];
}

#pragma mark -
- (void)focusAnimation:(CGPoint)point
{
    self.focusImageView.center = point;
    self.focusImageView.alpha = 1.0f;

    dispatch_async(dispatch_get_main_queue(), ^{
        [UIView animateWithDuration:0.5f animations:^{
            self.focusImageView.alpha = 0.0f;
        } completion:NULL];
    });
}

#pragma mark - dealloc
- (void)dealloc
{
    self.glView = nil;
    self.cameraProcessor = nil;
    self.videoRecorder = nil;

    self.switchCameraButton = nil;
    self.flashButton = nil;
    self.slider = nil;
    self.shutterImageView = nil;
    self.focusImageView = nil;
    self.timerLabel = nil;
}

@end
