//
//  AVCaptureCamera.h
//  GLCameraTemplate
//
//  Created by kazuki_tanaka on 2013/05/03.
//  Copyright (c) 2013年 kazukitanaka. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <AVFoundation/AVFoundation.h>

@protocol AVCaptureCameraDelegate <NSObject>

- (void)processCameraFrame:(CMSampleBufferRef)sampleBuffer mediaType:(NSString *)mediaType;

@end

@interface AVCaptureCamera : NSObject

- (id)initWithDelelgate:(id)aDelegate;

@end
