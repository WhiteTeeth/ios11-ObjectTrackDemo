//
//  CVPixelBufferUtils.m
//  ObjectTrackDemo
//
//  Created by baiya on 2017/6/29.
//  Copyright © 2017年 Maxcw. All rights reserved.
//

#import "CVPixelBufferUtils.h"

@implementation CVPixelBufferUtils


// 将CVPixelBufferRef 转化为cv::Mat，传参的buffer格式为BGRA，不过其他四通道格式应该也适用
//+ (cv::Mat)matFromPixelBuffer:(CVPixelBufferRef)buffer
//{
//    CVPixelBufferLockBaseAddress(buffer, 0);
//    
//    unsigned char *base = (unsigned char *)CVPixelBufferGetBaseAddress( buffer );
//    size_t width = CVPixelBufferGetWidth( buffer );
//    size_t height = CVPixelBufferGetHeight( buffer );
//    size_t stride = CVPixelBufferGetBytesPerRow( buffer );
//    OSType type =  CVPixelBufferGetPixelFormatType(buffer);
//    size_t extendedWidth = stride / 4;  // each pixel is 4 bytes/32 bits
//    cv::Mat bgraImage = cv::Mat( (int)height, (int)extendedWidth, CV_8UC4, base );
//    
//    CVPixelBufferUnlockBaseAddress(buffer,0);
//    
//    return bgraImage;
//}


/*
 * 注意旋转SampleBuffer 为argb或者bgra格式，其他格式可能不支持
 * rotationConstant:
 *  0 -- rotate 0 degrees (simply copy the data from src to dest)
 *  1 -- rotate 90 degrees counterclockwise
 *  2 -- rotate 180 degress
 *  3 -- rotate 270 degrees counterclockwise
 */
+ (CVPixelBufferRef)rotateBuffer:(CMSampleBufferRef)sampleBuffer withConstant:(uint8_t)rotationConstant
{
    CVImageBufferRef imageBuffer        = CMSampleBufferGetImageBuffer(sampleBuffer);
    CVPixelBufferLockBaseAddress(imageBuffer, 0);
    
    OSType pixelFormatType              = CVPixelBufferGetPixelFormatType(imageBuffer);
    
//    NSAssert(pixelFormatType == kCVPixelFormatType_32ARGB, @"Code works only with 32ARGB format. Test/adapt for other formats!");
    
    const size_t kAlignment_32ARGB      = 32;
    const size_t kBytesPerPixel_32ARGB  = 4;
    
    size_t bytesPerRow                  = CVPixelBufferGetBytesPerRow(imageBuffer);
    size_t width                        = CVPixelBufferGetWidth(imageBuffer);
    size_t height                       = CVPixelBufferGetHeight(imageBuffer);
    
    BOOL rotatePerpendicular            = (rotationConstant == 1) || (rotationConstant == 3); // Use enumeration values here
    const size_t outWidth               = rotatePerpendicular ? height : width;
    const size_t outHeight              = rotatePerpendicular ? width  : height;
    
    size_t bytesPerRowOut               = kBytesPerPixel_32ARGB * ceil(outWidth * 1.0 / kAlignment_32ARGB) * kAlignment_32ARGB;
    
    const size_t dstSize                = bytesPerRowOut * outHeight * sizeof(unsigned char);
    
    void *srcBuff                       = CVPixelBufferGetBaseAddress(imageBuffer);
    
    unsigned char *dstBuff              = (unsigned char *)malloc(dstSize);
    
    vImage_Buffer inbuff                = {srcBuff, height, width, bytesPerRow};
    vImage_Buffer outbuff               = {dstBuff, outHeight, outWidth, bytesPerRowOut};
    
    uint8_t bgColor[4]                  = {0, 0, 0, 0};
    
    vImage_Error err                    = vImageRotate90_ARGB8888(&inbuff, &outbuff, rotationConstant, bgColor, 0);
    if (err != kvImageNoError)
    {
        NSLog(@"%ld", err);
    }
    
    CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
    
    CVPixelBufferRef rotatedBuffer      = NULL;
    CVPixelBufferCreateWithBytes(NULL,
                                 outWidth,
                                 outHeight,
                                 pixelFormatType,
                                 outbuff.data,
                                 bytesPerRowOut,
                                 freePixelBufferDataAfterRelease,
                                 NULL,
                                 NULL,
                                 &rotatedBuffer);
    
    return rotatedBuffer;
}

void freePixelBufferDataAfterRelease(void *releaseRefCon, const void *baseAddress)
{
    // Free the memory we malloced for the vImage rotation
    free((void *)baseAddress);
}

@end
