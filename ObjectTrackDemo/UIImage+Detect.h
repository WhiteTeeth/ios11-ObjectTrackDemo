//
//  UIImage+Detect.h
//  TextAndHorizonDetectionDemo
//
//  Created by engleliu on 2017/6/22.
//  Copyright © 2017年 Maxcw. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Vision/Vision.h>

@interface UIImage (Detect)

- (void)detectTextWithImage:(nullable VNRequestCompletionHandler)completionHandler;

@end
