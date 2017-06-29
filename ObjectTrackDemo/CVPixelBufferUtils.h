//
//  CVPixelBufferUtils.h
//  ObjectTrackDemo
//
//  Created by baiya on 2017/6/29.
//  Copyright © 2017年 Maxcw. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <Accelerate/Accelerate.h>
//#import <opencv2/opencv.hpp>

@interface CVPixelBufferUtils : NSObject

// 将CVPixelBufferRef 转化为cv::Mat，传参的buffer格式为BGRA，不过其他四通道格式应该也适用
//+ (cv::Mat)matFromPixelBuffer:(CVPixelBufferRef)buffer;

/*
 * 注意旋转SampleBuffer 为argb或者bgra格式，其他格式可能不支持
 * rotationConstant:
 *  0 -- rotate 0 degrees (simply copy the data from src to dest)
 *  1 -- rotate 90 degrees counterclockwise
 *  2 -- rotate 180 degress
 *  3 -- rotate 270 degrees counterclockwise
 */
+ (CVPixelBufferRef)rotateBuffer:(CMSampleBufferRef)sampleBuffer withConstant:(uint8_t)rotationConstant;

@end
