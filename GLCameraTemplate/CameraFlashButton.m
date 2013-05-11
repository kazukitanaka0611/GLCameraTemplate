//
//  CameraFlashButton.m
//  GLCameraTemplate
//
//  Created by kazuki_tanaka on 2013/05/09.
//  Copyright (c) 2013年 kazukitanaka. All rights reserved.
//

#import "CameraFlashButton.h"

#import <QuartzCore/QuartzCore.h>

@interface CameraFlashButton()

@property (nonatomic, assign) CGRect baseFrame;
@property (nonatomic, assign) CGRect expandFrame;

@property (nonatomic, strong) NSMutableArray *lableList;

@property (nonatomic, assign) BOOL isExpanded;
@property (nonatomic, assign) NSInteger selectedItemIndex;

@end

@implementation CameraFlashButton

#pragma mark -
- (id)initWithPosition:(CGPoint)point tiltle:(NSString *)title
           buttonNames:(NSArray *)buttonNames selectItem:(NSInteger)selectItem
{
    self.baseFrame = CGRectMake(point.x, point.y, 91.0f, 32.0f);

    self.expandFrame = CGRectMake(point.x, point.y, 47.0f + (44.0f  * buttonNames.count), 32.0f);
    
    if (self = [super initWithFrame:self.baseFrame])
    {
        // Title Label
        UILabel *titleLable = [[UILabel alloc] initWithFrame:
                               CGRectMake(8.0f, 9.0f, 35.0f, 15.0f)];
        titleLable.text = title;
        titleLable.font = [UIFont systemFontOfSize:12.0f];
        titleLable.textColor = [UIColor blackColor];
        titleLable.backgroundColor = [UIColor clearColor];
        [self addSubview:titleLable];

        // Lable List
        self.lableList = [[NSMutableArray alloc] init];

        NSInteger index = 0;

        for (NSString *buttonName in buttonNames)
        {
            // Lable
            UILabel *label = [[UILabel alloc] initWithFrame:
                              CGRectMake(45.0f + (44.0f * index), -3.0f, 44.0f, 26.0f)];
            label.text = buttonName;
            label.font = [UIFont systemFontOfSize:12.0f];
            label.textColor = [UIColor blackColor];
            label.backgroundColor = [UIColor clearColor];
#if __IPHONE_OS_VERSION_MIN_REQUIRED >= 60000
            label.textAlignment = NSTextAlignmentCenter;
#else
            label.textAlignment = UITextAlignmentCenter;
#endif
            [self addSubview:label];

            // Lable List add Label
            [self.lableList addObject:label];
            index++;
        }

        [self addTarget:self action:@selector(chooseLabel:forEvent:) forControlEvents:UIControlEventTouchUpInside];

        self.backgroundColor = [UIColor clearColor];

        CALayer *layer = self.layer;
        layer.backgroundColor = [[UIColor colorWithWhite:1.0f alpha:0.2f] CGColor];
        layer.borderWidth = 1.0f;
        layer.cornerRadius = 15.0f;

        self.isExpanded = YES;
        [self setSelectedItem:selectItem];
    }
    
    return self;
}

#pragma mark -
- (NSInteger)selectedItem
{
    return self.selectedItemIndex;
}

#pragma mark -
- (void)setSelectedItem:(NSInteger)selectedItem
{
    if (selectedItem < self.lableList.count)
    {
        CGRect leftShrink = CGRectMake(45.0f, -3.0f, 0.0f, 39.0f);
        CGRect rightShink = CGRectMake(89.0f, -3.0f, 0.0f, 39.0f);
        CGRect middleExpanded = CGRectMake(45.0f, -3.0f, 44.0f, 39.0f);

        NSInteger count = 0;

        if (self.isExpanded)
        {
            [UIView beginAnimations:nil context:NULL];
        }

        for (UILabel *label in self.lableList)
        {
            label.font = [UIFont systemFontOfSize:12.0f];
            
            if (count < selectedItem)
            {
                label.frame = leftShrink;
            }
            else if(count > selectedItem)
            {
                label.frame = rightShink;
            }
            else if(count == selectedItem)
            {
                label.frame = middleExpanded;
            }

            count++;
        }

        if (self.isExpanded)
        {
            self.layer.frame = self.baseFrame;
            [UIView commitAnimations];
            self.isExpanded = NO;
        }

        if (self.selectedItemIndex != selectedItem)
        {
            self.selectedItemIndex = selectedItem;
            [self sendActionsForControlEvents:UIControlEventValueChanged];
        }
    }
}

#pragma mark -
- (void)chooseLabel:(id)sender forEvent:(UIEvent *)event
{
    [UIView beginAnimations:nil context:NULL];

    if (!self.isExpanded)
    {
        self.isExpanded = YES;

        NSInteger index = 0;

        for (UILabel *label in self.lableList)
        {
            if (index == self.selectedItemIndex)
            {
                label.font = [UIFont boldSystemFontOfSize:12.0f];
            }
            else
            {
                label.textColor = [UIColor colorWithWhite:0.0f alpha:0.8f];
                label.font = [UIFont systemFontOfSize:12.0f];
            }

            label.frame = CGRectMake(45.0f + (44.0f * index), -3.0f, 44.0f, 39.0f);

            index++;
        }

        self.layer.frame = self.expandFrame;
    }
    else
    {
        BOOL inside = NO;

        NSInteger index = 0;

        for (UILabel *label in self.lableList)
        {
            if ([label pointInside:[[[event allTouches] anyObject] locationInView:label] withEvent:event])
            {
                label.frame = CGRectMake(45.0f, -3.0f, 44.0f, 39.0f);
                inside = YES;
                break;
            }
            
            index++;
        }

        if(inside)
        {
            [self setSelectedItem:index];
        }
    }

    [UIView commitAnimations];
}

#pragma mark - dealloc
- (void)dealloc
{
    self.lableList = nil;
}

@end
