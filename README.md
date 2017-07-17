# ios11-ObjectTrackDemo


ios 11 新出了[Vision](https://developer.apple.com/documentation/vision) 框架，提供了人脸识别、物体检测、物体跟踪等技术。本文将通过一个Demo简单介绍如何使用Vision框架进行物体检测和物体跟踪。本文Demo可以在[Github](https://github.com/WhiteTeeth/ios11-ObjectTrackDemo)上下载。


<!--more-->

# 1. 关于Vision框架

Vision 是伴随ios 11 推出的基于CoreML的图形处理框架。运用高性能图形处理和视觉技术，可以对图像和视频进行人脸检测、特征点检测和场景识别等。

![image](http://7punko.com1.z0.glb.clouddn.com/blog/ios11%E4%BD%BF%E7%94%A8vision%E5%BC%80%E5%A7%8B%E7%89%A9%E4%BD%93%E8%B7%9F%E8%B8%AA/vision%E6%A1%86%E6%9E%B6.jpg)


# 2. 使用vision 进行物体识别

## 环境

Xcode 9 + ios 11


## 获取图像数据

该步骤假设你已经调起系统相机，并获得 `CMSampleBufferRef` 数据。注意返回的simpleBuffer 方向和UIView 显示方向不一致，所以先对simpleBuffer 旋转到正确的方向。

当然也可以不进行旋转，但是要保证后续坐标转换的一致性。


```
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


```


## 物体检测

拿到图像数据后就可以进行物体检测，物体检测流程很简单：

1. 创建一个物体检测请求 VNDetectRectanglesRequest
2. 根据数据源(pixelBuffer 或者 UIImage)创建一个 VNImageRequestHandler
3. 调用[VNImageRequestHandler performRequests] 执行检测


```

- (void)detectObjectWithPixelBuffer:(CVPixelBufferRef)pixelBuffer
{
    CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();
    
    void (^ VNRequestCompletionHandler)(VNRequest *request, NSError * _Nullable error) = ^(VNRequest *request, NSError * _Nullable error)
    {
        CFAbsoluteTime end = CFAbsoluteTimeGetCurrent();
        
        NSLog(@"检测耗时： %f", end - start);
        if (!error && request.results.count > 0) {
            // TODO 这里处理检测结果
            return ;
        }
    };
    
    VNImageRequestHandler *handler = [[VNImageRequestHandler alloc] initWithCVPixelBuffer:pixelBuffer options:@{}];
    VNDetectRectanglesRequest *request = [[VNDetectRectanglesRequest alloc] initWithCompletionHandler:VNRequestCompletionHandler];
    request.minimumAspectRatio = 0.1;	// 最小长宽比设为0.1
    request.maximumObservations = 0;		// 不限制检测结果
    [handler performRequests:@[request] error:nil];
}

```


## 显示检测结果


物体检测返回结果是一个 `VNDetectedObjectObservation` 的结果集，包含`confidence`, `uuid` 和 `boundingBox`三种属性。 因为vision坐标系类似opengl的纹理坐标系，以屏幕左下角为坐标原点，并做了归一化。所以将显示结果投影到屏幕时，还需要进行坐标系的转换。

三种坐标系的区别：

坐标系 | 原点 | 长宽  
---- | ---- | ------
UIKit坐标系 | 左上角 | 屏幕大小 
AVFoundation坐标系 | 左上角 | 0 - 1 
Vision坐标系 | 左下角 | 0 - 1 


显示代码如下，使用`CGAffineTransform `进行坐标转换，并根据转换后矩形绘制红色边框。同时打印`confidence`信息到屏幕上。


```

- (void)overlayImageWithSize:(CGSize)size
{
    
    NSDictionary *lastObsercationDicCopy = [NSDictionary dictionaryWithDictionary:self.lastObsercationsDic];
    NSArray *keyArr = [lastObsercationDicCopy allKeys];
    
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(size.width, size.height)];
    
    void (^UIGraphicsImageDrawingActions)(UIGraphicsImageRendererContext *rendererContext) = ^(UIGraphicsImageRendererContext *rendererContext)
    {
    	 // 将vision坐标转换为屏幕坐标
        CGAffineTransform  transform = CGAffineTransformIdentity;
        transform = CGAffineTransformScale(transform, size.width, -size.height);
        transform = CGAffineTransformTranslate(transform, 0, -1);
        
        for (NSString *uuid in keyArr) {
            VNDetectedObjectObservation *rectangleObservation = lastObsercationDicCopy[uuid];
            
            // 绘制红框
            [[UIColor redColor] setStroke];
            UIBezierPath *path = [UIBezierPath bezierPathWithRect:CGRectApplyAffineTransform(rectangleObservation.boundingBox, transform)];
            path.lineWidth = 4.0f;
            [path stroke];
            
        }
    };
    
    UIImage *overlayImage = [renderer imageWithActions:UIGraphicsImageDrawingActions];
    
    NSMutableString *trackInfoStr = [NSMutableString string];
    
    for (NSString *uuid in keyArr) {
        VNDetectedObjectObservation *rectangleObservation = lastObsercationDicCopy[uuid];
        
        [trackInfoStr appendFormat:@"置信度 ： %.2f \n", rectangleObservation.confidence];
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        
        self.highlightView.image = overlayImage;
        
        self.infoLabel.text = trackInfoStr;
    });
}   
    

```


# 3. 物体跟踪

物体跟踪需要处理连续的视频帧，所以需要创建`VNSequenceRequestHandler`处理多帧图像。同时还需要一个`VNDetectedObjectObservation`对象 做为参考源。你可以使用物体检测的结果，或者指定一个矩形作为物体跟踪的参考源。注意因为坐标系不同，如果直接指定矩形作为参考源时，需要事先进行正确的坐标转换。

跟踪多物体时，可以使用`VNDetectedObjectObservation.uuid`区分跟踪对象，并做相应处理。


```

- (void)objectTrackWithPixelBuffer:(CVPixelBufferRef)pixelBuffer
{

    if (!self.sequenceHandler) {
        self.sequenceHandler = [[VNSequenceRequestHandler alloc] init];
    }
    
    NSArray<NSString *> *obsercationKeys = self.lastObsercationsDic.allKeys;
    
    NSMutableArray<VNTrackObjectRequest *> *obsercationRequest = [NSMutableArray array];
    
    CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();
    for (NSString *key in obsercationKeys) {
        
        VNDetectedObjectObservation *obsercation = self.lastObsercationsDic[key];
        
        VNTrackObjectRequest *trackObjectRequest = [[VNTrackObjectRequest alloc] initWithDetectedObjectObservation:obsercation completionHandler:^(VNRequest * _Nonnull request, NSError * _Nullable error) {
            
            CFAbsoluteTime end = CFAbsoluteTimeGetCurrent();
            NSLog(@"跟踪耗时： %f", end - start);
            
            if (nil == error && request.results.count > 0) {
                
                // TODO 处理跟踪结果
                
                
            } else {
                // 跟踪失败处理
                
            }
        }];
        trackObjectRequest.trackingLevel = VNRequestTrackingLevelAccurate;
        
        [obsercationRequest addObject:trackObjectRequest];
    }
    
    
    NSError *error = nil;
    [self.sequenceHandler performRequests:obsercationRequest onCVPixelBuffer:pixelBuffer error:&error];
    
}

```



## 效果图

![image](http://7punko.com1.z0.glb.clouddn.com/blog/ios11%E4%BD%BF%E7%94%A8vision%E5%BC%80%E5%A7%8B%E7%89%A9%E4%BD%93%E8%B7%9F%E8%B8%AA/%E6%95%88%E6%9E%9C%E5%9B%BE.jpg)



# 4. 性能

## 测试机型

iphone6p ios 11.0(15A5318g)

1/10 取帧率


## 物体检测

### 内存

稳定在40M左右

![image](http://7punko.com1.z0.glb.clouddn.com/blog/ios11%E4%BD%BF%E7%94%A8vision%E5%BC%80%E5%A7%8B%E7%89%A9%E4%BD%93%E8%B7%9F%E8%B8%AA/%E7%89%A9%E4%BD%93%E6%A3%80%E6%B5%8B%E5%86%85%E5%AD%98_iphone6p.png)

### CPU

达到了125%的使用量


![image](http://7punko.com1.z0.glb.clouddn.com/blog/ios11%E4%BD%BF%E7%94%A8vision%E5%BC%80%E5%A7%8B%E7%89%A9%E4%BD%93%E8%B7%9F%E8%B8%AA/%E7%89%A9%E4%BD%93%E6%A3%80%E6%B5%8BCPU_iphone6p.png)

### 电量

![image](http://7punko.com1.z0.glb.clouddn.com/blog/ios11%E4%BD%BF%E7%94%A8vision%E5%BC%80%E5%A7%8B%E7%89%A9%E4%BD%93%E8%B7%9F%E8%B8%AA/%E7%89%A9%E4%BD%93%E6%A3%80%E6%B5%8B%E7%94%B5%E9%87%8F_iphone6p.png)


### 耗时

平均在50ms左右

![image](http://7punko.com1.z0.glb.clouddn.com/blog/ios11%E4%BD%BF%E7%94%A8vision%E5%BC%80%E5%A7%8B%E7%89%A9%E4%BD%93%E8%B7%9F%E8%B8%AA/%E7%89%A9%E4%BD%93%E6%A3%80%E6%B5%8B%E8%80%97%E6%97%B6_iphone6p.png)


## 物体跟踪

### 内存

和物体检测一样在40M左右

![image](http://7punko.com1.z0.glb.clouddn.com/blog/ios11%E4%BD%BF%E7%94%A8vision%E5%BC%80%E5%A7%8B%E7%89%A9%E4%BD%93%E8%B7%9F%E8%B8%AA/%E7%89%A9%E4%BD%93%E8%B7%9F%E8%B8%AA%E5%86%85%E5%AD%98_iphone6p.png)

### CPU

相对低些，但也有100%的使用率

![image](http://7punko.com1.z0.glb.clouddn.com/blog/ios11%E4%BD%BF%E7%94%A8vision%E5%BC%80%E5%A7%8B%E7%89%A9%E4%BD%93%E8%B7%9F%E8%B8%AA/%E7%89%A9%E4%BD%93%E8%B7%9F%E8%B8%AACPU_iphone6p.png)

### 电量

![image](http://7punko.com1.z0.glb.clouddn.com/blog/ios11%E4%BD%BF%E7%94%A8vision%E5%BC%80%E5%A7%8B%E7%89%A9%E4%BD%93%E8%B7%9F%E8%B8%AA/%E7%89%A9%E4%BD%93%E8%B7%9F%E8%B8%AA%E7%94%B5%E9%87%8F_iphone6p.png)

### 耗时

相对低些，20-40ms不等

![image](http://7punko.com1.z0.glb.clouddn.com/blog/ios11%E4%BD%BF%E7%94%A8vision%E5%BC%80%E5%A7%8B%E7%89%A9%E4%BD%93%E8%B7%9F%E8%B8%AA/%E7%89%A9%E4%BD%93%E8%B7%9F%E8%B8%AA%E8%80%97%E6%97%B6iphone6p.png)


# 5. 总结

Vision是一个比较好用的框架，性能也不错。除了物体跟踪，Vision还提供**图像分类**、**人脸识别**、**人脸特征提取**、**人脸追踪**、**文字识别**等功能，使用方法和物体检测类似，本文就不再进行过多描述。



## 参考文档

[Getting Started with Vision](https://github.com/jeffreybergier/Blog-Getting-Started-with-Vision)


