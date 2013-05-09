//
//  CameraFlashButton.h
//  GLCameraTemplate
//
//  Created by kazuki_tanaka on 2013/05/09.
//  Copyright (c) 2013年 kazukitanaka. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface CameraFlashButton : UIButton

- (id)initWithPosition:(CGPoint)point tiltle:(NSString *)title
           buttonNames:(NSArray *)buttonNames selectItem:(NSInteger)selectItem;

@end
