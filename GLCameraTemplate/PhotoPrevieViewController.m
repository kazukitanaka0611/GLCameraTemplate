//
//  PhotoPrevieViewController.m
//  GLCameraTemplate
//
//  Created by kazuki_tanaka on 2013/05/03.
//  Copyright (c) 2013年 kazukitanaka. All rights reserved.
//

#import "PhotoPrevieViewController.h"

@interface PhotoPrevieViewController ()

@property (nonatomic, strong) UIImage *image;

@end

@implementation PhotoPrevieViewController

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
- (void)resizeImage:(UIImage *)aOriginalImage imageView:(UIImageView *)aImageView
{
    float aspect = aOriginalImage.size.height / aOriginalImage.size.width;
    float canvasRectWidth = aImageView.bounds.size.width;
    float canvasRectHeight = (canvasRectWidth * aspect);

    if (canvasRectHeight > [[UIScreen mainScreen] bounds].size.height)
    {
        canvasRectHeight = [[UIScreen mainScreen] bounds].size.height;
        canvasRectWidth = canvasRectHeight / aspect;
    }

    CGPoint canvasCenter = aImageView.center;
    CGRect	canvasRect = CGRectMake(0.0f, 0.0f, canvasRectWidth, canvasRectHeight);

    aImageView.bounds = canvasRect;
    aImageView.center = canvasCenter;

    UIGraphicsBeginImageContext(canvasRect.size);
    [aImageView.image drawInRect:canvasRect];
    [aOriginalImage drawInRect:canvasRect];
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    aImageView.image = newImage;

    UIGraphicsEndImageContext();
}

#pragma mark - dealloc
- (void)dealloc
{
    self.image = nil;
}

@end
