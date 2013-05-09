//
//  GLCameraTemplateViewController.m
//  GLCameraTemplate
//
//  Created by kazuki_tanaka on 2013/05/01.
//  Copyright (c) 2013年 kazukitanaka. All rights reserved.
//

#import "GLCameraTemplateViewController.h"

#import <AudioToolbox/AudioToolbox.h>
#import <AssetsLibrary/AssetsLibrary.h>

#import "OpenGLView.h"
#import "AVCaptureCamera.h"
#import "VideoRecorder.h"

#import "CameraFlashButton.h"
#import "PhotoPrevieViewController.h"

@interface GLCameraTemplateViewController ()

@property (nonatomic, strong) OpenGLView *glView;
@property (nonatomic, strong) AVCaptureCamera *camera;
@property (nonatomic, strong) VideoRecorder *videoRecorder;

@property (nonatomic, strong) UIButton *switchCameraButton;
@property (nonatomic, strong) CameraFlashButton *flashButton;

@end

@implementation GLCameraTemplateViewController

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

    // Camera
    self.camera = [[AVCaptureCamera alloc] initWithDelelgate:self];

    // Video Recorder
    self.videoRecorder = [[VideoRecorder alloc] init];

    // OpenGL View
    self.glView = [[OpenGLView alloc] initWithFrame:self.view.bounds];
    [self.view addSubview:self.glView];

    // Camera Switch Button
    self.switchCameraButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.switchCameraButton.frame = CGRectMake(245.0f, 10.0f, 70.0f, 35.0f);
    self.switchCameraButton.backgroundColor = [UIColor clearColor];
    CALayer *layer = self.switchCameraButton.layer;
    layer.backgroundColor = [[UIColor colorWithWhite:1.0f alpha:0.2f] CGColor];
    layer.borderWidth = 1.0f;
    layer.cornerRadius = 15.0f;
    [self.switchCameraButton addTarget:self
                           action:@selector(switchCameraButtonClick:)
                 forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.switchCameraButton];
    
    if (1 == self.camera.deviceCount)
    {
        self.switchCameraButton.hidden = YES;
    }

    // Camera Flash button
    self.flashButton = [[CameraFlashButton alloc] initWithPosition:CGPointMake(10, 10)
                                                            tiltle:@"flash"
                                                       buttonNames:@[@"Auto", @"ON", @"OFF"]
                                                        selectItem:0];
    [self.view addSubview:self.flashButton];
    
    if (!self.camera.hasFlash)
    {
        self.flashButton.hidden = YES;
    }
    
    // UIToolbar
    UIToolbar *toolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, self.view.frame.size.height - 44.0f,
                                                                     self.view.frame.size.width, 44.0f)];
    [self.view addSubview:toolbar];

    // Shutter Button
    UIBarButtonItem *shutterButtonItem = [[UIBarButtonItem alloc]initWithBarButtonSystemItem:UIBarButtonSystemItemCamera
                                                                                      target:self
                                                                                      action:@selector(shutterButtonItemClick:)];

    UIBarButtonItem *recordButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"rec"
                                                                         style:UIBarButtonItemStyleBordered
                                                                        target:self
                                                                        action:@selector(recordBarButtonItemClick:)];
    toolbar.items = @[ shutterButtonItem, recordButtonItem ];

    // TapGestureRecognizer
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapGestureHandler:)];
    [self.glView addGestureRecognizer:tapGesture];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma - mark
- (void)processCameraFrame:(CMSampleBufferRef)sampleBuffer mediaType:(NSString *)mediaType
{
    if (self.videoRecorder.isRecording)
    {
        CVPixelBufferRef pixelBuffer = [self.glView recordView:self.videoRecorder.adaptor.pixelBufferPool];
        
        [self.videoRecorder writeSample:sampleBuffer mediaType:mediaType pixelBuffer:pixelBuffer];
    }

    if (mediaType == AVMediaTypeVideo)
    {
        CVImageBufferRef cameraFrame = CMSampleBufferGetImageBuffer(sampleBuffer);

        CVPixelBufferLockBaseAddress(cameraFrame, 0);

        [self.glView drawFrame:cameraFrame];

        CVPixelBufferUnlockBaseAddress(cameraFrame, 0);
    }
}

#pragma - mark
- (void)captureDidStartRinning
{
    [self.camera setFocus:self.glView.center];
}

#pragma - mark
- (void)shutterButtonItemClick:(UIBarButtonItem *)barButtonItem
{
    AudioServicesPlaySystemSound(1108);

    __block UIImage *saveImage = [self.glView convertUIImage];

    ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
    [library writeImageToSavedPhotosAlbum:saveImage.CGImage
                               orientation:(ALAssetOrientation)saveImage.imageOrientation
                           completionBlock:^(NSURL *assetURL, NSError *error){

                               PhotoPrevieViewController *controller = [[PhotoPrevieViewController alloc]initWithImage:saveImage];
                               [self presentViewController:controller animated:YES completion:NULL];
                           }];
}

#pragma mark -
- (void)recordBarButtonItemClick:(UIBarButtonItem *)barButtonItem
{
    if (!self.videoRecorder.isRecording)
    {
        AudioServicesAddSystemSoundCompletion(1117, NULL, NULL, endSound, (__bridge void*)self);
        AudioServicesPlaySystemSound(1117);

        if (self.camera.hasFlash)
        {
            self.flashButton.hidden = YES;
        }

        if (1 < self.camera.deviceCount)
        {
            self.switchCameraButton.hidden = YES;
        }
    }
    else
    {
        AudioServicesPlaySystemSound(1118);

        if (self.camera.hasFlash
        && !self.camera.isFrontCamera)
        {
            self.flashButton.hidden = NO;
        }

        if (1 < self.camera.deviceCount)
        {
            self.switchCameraButton.hidden = NO;
        }
        
        // Stop Record
        NSURL *movieURL = [self.videoRecorder stopRecording];

        [self.glView stopRecording];

        ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
        [library writeVideoAtPathToSavedPhotosAlbum:movieURL
                                    completionBlock:^(NSURL *assetURL, NSError *error){
        }];
    }
}

#pragma - mark
static void endSound (SystemSoundID soundID, void *myself)
{
    [((__bridge GLCameraTemplateViewController *)myself).videoRecorder
     startRecording:((__bridge GLCameraTemplateViewController *)myself).glView.bounds];

    [((__bridge GLCameraTemplateViewController *)myself).glView startRecording];
    
    AudioServicesRemoveSystemSoundCompletion (soundID);
}

#pragma mark -
- (void)switchCameraButtonClick:(UIButton *)button
{
    [self.camera switchCamera];

    if (self.camera.isFrontCamera)
    {
        self.flashButton.hidden = YES;
    }
    else
    {
        self.flashButton.hidden = NO;
    }
}

#pragma mark -
- (void)tapGestureHandler:(UITapGestureRecognizer *)recogniser
{
    CGPoint point = [recogniser locationInView:self.glView];

    [self.camera setFocus:point];
}

#pragma mark - dealloc
- (void)dealloc
{
    self.glView = nil;
    self.camera = nil;
    self.videoRecorder = nil;
}

@end
