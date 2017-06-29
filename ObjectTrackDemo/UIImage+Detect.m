//
//  UIImage+Detect.m
//  ObjectTrackDemo
//
//  Created by baiya on 2017/6/22.
//  Copyright © 2017年 Maxcw. All rights reserved.
//

#import "UIImage+Detect.h"

@implementation UIImage (Detect)

// 使用image进行文字检测
- (void)detectTextWithImage:(nullable VNRequestCompletionHandler)completionHandler
{
    UIImage *image = self;
    if(nil == image)
        return;

    VNImageRequestHandler *handler = [[VNImageRequestHandler alloc] initWithCGImage:image.CGImage options:@{}];
    VNDetectTextRectanglesRequest *request = [[VNDetectTextRectanglesRequest alloc] initWithCompletionHandler:completionHandler];
    
    request.reportCharacterBoxes = YES;
    [handler performRequests:@[request] error:nil];
}

@end
