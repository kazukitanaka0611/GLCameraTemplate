//
//  PhotoPrevieViewController.m
//  GLCameraTemplate
//
//  Created by kazuki_tanaka on 2013/05/03.
//  Copyright (c) 2013年 kazukitanaka. All rights reserved.
//

#import "PhotoPreviewViewController.h"

@interface PhotoPreviewViewController ()

@property (nonatomic, strong) UIImage *image;

@end

@implementation PhotoPreviewViewController

- (id)initWithImage:(UIImage *)image
{
    self = [super init];

    if (self)
    {
        self.image = image;
    }

    return self;
}

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

    // UIImageView
    UIImageView *imageView = [[UIImageView alloc] initWithFrame:self.view.bounds];
    [self.view addSubview:imageView];

    // Risize Image
    [self resizeImage:self.image imageView:imageView];
    
    // UIToolbar
    UIToolbar *toolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, self.view.frame.size.height - 44,
                                                                     self.view.frame.size.width, 44)];
    [self.view addSubview:toolbar];

    // back Button
    UIBarButtonItem *backButtonItem = [[UIBarButtonItem alloc]initWithTitle:@"Back"
                                                                      style:UIBarButtonItemStyleBordered
                                                                     target:self
                                                                     action:@selector(backButtonItemClick:)];
    toolbar.items = @[ backButtonItem ];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark -
- (void)backButtonItemClick:(UIBarButtonItem *)barButtonItem
{
    [self dismissViewControllerAnimated:YES completion:NULL];
}

#pragma mark -
- (void)resizeImage:(UIImage *)originalImage imageView:(UIImageView *)imageView
{
    float aspect = originalImage.size.height / originalImage.size.width;
    float canvasRectWidth = imageView.bounds.size.width;
    float canvasRectHeight = (canvasRectWidth * aspect);

    if (canvasRectHeight > [[UIScreen mainScreen] bounds].size.height)
    {
        canvasRectHeight = [[UIScreen mainScreen] bounds].size.height;
        canvasRectWidth = canvasRectHeight / aspect;
    }

    CGPoint canvasCenter = imageView.center;
    CGRect	canvasRect = CGRectMake(0.0f, 0.0f, canvasRectWidth, canvasRectHeight);

    imageView.bounds = canvasRect;
    imageView.center = canvasCenter;

    UIGraphicsBeginImageContext(canvasRect.size);
    [imageView.image drawInRect:canvasRect];
    [originalImage drawInRect:canvasRect];
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    imageView.image = newImage;

    UIGraphicsEndImageContext();
}

#pragma mark - dealloc
- (void)dealloc
{
    self.image = nil;
}

@end
