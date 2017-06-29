//
//  ViewController.m
//  ObjectTrackDemo
//
//  Created by baiya on 2017/6/8.
//  Copyright © 2017年 Maxcw. All rights reserved.
//

#import "ViewController.h"
#import <Vision/Vision.h>
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <CoreVideo/CoreVideo.h>
#import <CoreMedia/CoreMedia.h>
#import <AVFoundation/AVCaptureDevice.h>
#import <AVFoundation/AVMediaFormat.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import <CoreLocation/CoreLocation.h>
#import "AVCamPreviewView.h"
#import <Accelerate/Accelerate.h>
#import "UIImage+Convert.h"
#import "UIImage+Orientation.h"
#import "CVPixelBufferUtils.h"



typedef NS_ENUM(uint8_t, MOVRotateDirection)
{
    MOVRotateDirectionNone = 0,
    MOVRotateDirectionCounterclockwise90,
    MOVRotateDirectionCounterclockwise180,
    MOVRotateDirectionCounterclockwise270,
    MOVRotateDirectionUnknown
};

@interface ViewController ()<AVCaptureVideoDataOutputSampleBufferDelegate>

//@property (nullable, nonatomic, strong) UIImageView *imageView1;
@property (nullable, nonatomic, strong) UIImageView *highlightView;
@property (nullable, nonatomic, strong) UIImageView *bgImgView;

@property (nonatomic, retain) AVCaptureSession *captureSession;
@property (nonatomic, retain) AVCamPreviewView *preView;

@property (nonatomic, strong) UILabel *infoLabel;

@property (nonatomic, assign) NSUInteger counter;   // 计数器

@property (nonatomic, retain) VNSequenceRequestHandler *sequenceHandler;
//@property (atomic, retain) VNDetectedObjectObservation *lastObsercation;

@property (nonatomic, retain) NSMutableDictionary<NSString *, VNDetectedObjectObservation *> *lastObsercationsDic;

@property (nonatomic, strong) dispatch_queue_t queue;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    
    
    AVCamPreviewView *preView = [[AVCamPreviewView alloc] initWithFrame:self.view.bounds];
    [self.view addSubview:preView];
    self.preView = preView;
    
    self.bgImgView = [[UIImageView alloc] initWithFrame:self.view.bounds];
    self.bgImgView.contentMode = UIViewContentModeScaleAspectFit;
    self.bgImgView.backgroundColor = [UIColor clearColor];
    [self.view addSubview:self.bgImgView];
    
    self.highlightView = [[UIImageView alloc] initWithFrame:self.view.bounds];
    self.highlightView.contentMode = UIViewContentModeScaleAspectFit;
    self.highlightView.backgroundColor = [UIColor clearColor];
    [self.view addSubview:self.highlightView];
    
    
    self.infoLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, self.view.bounds.size.height - 100, self.view.bounds.size.width, 100)];
    [self.view addSubview:self.infoLabel];
    self.infoLabel.backgroundColor = [UIColor colorWithRed:0x00 green:0x00 blue:0x00 alpha:0.4];
    self.infoLabel.textColor = [UIColor whiteColor];
    self.infoLabel.numberOfLines = 0;
    
    self.counter = 0;
    
    [self initCapture];
    
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"reset" style:UIBarButtonItemStylePlain target:self action:@selector(reset)];
}

- (void)reset
{
    
    [self.lastObsercationsDic removeAllObjects];
    self.lastObsercationsDic = nil;
    
    self.sequenceHandler = nil;
    
}

- (void)initCapture {
    AVCaptureDeviceInput *captureInput = [AVCaptureDeviceInput deviceInputWithDevice:[AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo]  error:nil];
    AVCaptureVideoDataOutput *captureOutput = [[AVCaptureVideoDataOutput alloc] init];
    captureOutput.alwaysDiscardsLateVideoFrames = YES;
    //captureOutput.minFrameDuration = CMTimeMake(1, 10);
    
    dispatch_queue_t queue = dispatch_queue_create("cameraQueue", NULL);
    self.queue = queue;
    [captureOutput setSampleBufferDelegate:self queue:queue];
    NSString* key = (NSString*)kCVPixelBufferPixelFormatTypeKey;
    NSNumber* value = [NSNumber numberWithUnsignedInt:kCVPixelFormatType_32BGRA];
    NSDictionary* videoSettings = [NSDictionary dictionaryWithObject:value forKey:key];
    [captureOutput setVideoSettings:videoSettings];
    self.captureSession = [[AVCaptureSession alloc] init];
    [self.captureSession addInput:captureInput];
    [self.captureSession addOutput:captureOutput];
    [self.captureSession startRunning];
    
    self.preView.session = self.captureSession;
}

#pragma mark AVCaptureSession delegate
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    if (self.counter % 10 != 0) {
        self.counter ++;
        return;
    }
    self.counter = 0;
    
    
    CVPixelBufferRef rotateBuffer = [CVPixelBufferUtils rotateBuffer:sampleBuffer withConstant:MOVRotateDirectionCounterclockwise270];
    
//    [self detectTextWithPixelBuffer:rotateBuffer];
    [self objectTrackWithPixelBuffer:rotateBuffer];
    
    CVBufferRelease(rotateBuffer);
    
}

// 使用pixelBuffer进行文字检测
//- (void)detectTextWithPixelBuffer:(CVPixelBufferRef)pixelBuffer
//{
//    void (^ VNRequestCompletionHandler)(VNRequest *request, NSError * _Nullable error) = ^(VNRequest *request, NSError * _Nullable error)
//    {
//        if (nil == error) {
//
//            size_t width = CVPixelBufferGetWidth(pixelBuffer);
//            size_t height = CVPixelBufferGetHeight(pixelBuffer);
//            CGSize size = CGSizeMake(width, height);
//            void (^UIGraphicsImageDrawingActions)(UIGraphicsImageRendererContext *rendererContext) = ^(UIGraphicsImageRendererContext *rendererContext)
//            {
//                //vision框架使用的坐标是为 0 -》 1， 原点为屏幕的左下角（跟UIKit不同），向右向上增加，妈蛋其实就是Opengl的纹理坐标系。
//                CGAffineTransform  transform= CGAffineTransformIdentity;
//                transform = CGAffineTransformScale(transform, size.width, -size.height);
//                transform = CGAffineTransformTranslate(transform, 0, -1);
//
//                for (VNTextObservation *textObservation in request.results)
//                {
//                    [[UIColor redColor] setStroke];
//                    [[UIBezierPath bezierPathWithRect:CGRectApplyAffineTransform(textObservation.boundingBox, transform)] stroke];
//                    for (VNRectangleObservation *rectangleObservation in textObservation.characterBoxes)
//                    {
//                        [[UIColor blueColor] setStroke];
//                        [[UIBezierPath bezierPathWithRect:CGRectApplyAffineTransform(rectangleObservation.boundingBox, transform)] stroke];
//                    }
//                }
//            };
//
//            UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:size];
//            UIImage *overlayImage = [renderer imageWithActions:UIGraphicsImageDrawingActions];
//
//            dispatch_async(dispatch_get_main_queue(), ^{
//                self.highlightView.image = overlayImage;
//            });
//        }
//    };
//
//    VNImageRequestHandler *handler = [[VNImageRequestHandler alloc] initWithCVPixelBuffer:pixelBuffer options:@{}];
//    VNDetectTextRectanglesRequest *request = [[VNDetectTextRectanglesRequest alloc] initWithCompletionHandler:VNRequestCompletionHandler];
//
//    request.reportCharacterBoxes = YES;
//    [handler performRequests:@[request] error:nil];
//}



// 物体检测
- (void)detectObjectWithPixelBuffer:(CVPixelBufferRef)pixelBuffer
{
    if (!self.lastObsercationsDic) {
        self.lastObsercationsDic = [NSMutableDictionary dictionary];
    }
    CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();
    
    void (^ VNRequestCompletionHandler)(VNRequest *request, NSError * _Nullable error) = ^(VNRequest *request, NSError * _Nullable error)
    {
        CFAbsoluteTime end = CFAbsoluteTimeGetCurrent();
        
        NSLog(@"检测耗时： %f", end - start);
        if (!error && request.results.count > 0) {
            for (VNDetectedObjectObservation *observation in request.results) {
                [self.lastObsercationsDic setObject:observation forKey:observation.uuid.UUIDString];
            }
            
            [self objectTrackWithPixelBuffer:pixelBuffer];
            
            return ;
        }
    };
    
    VNImageRequestHandler *handler = [[VNImageRequestHandler alloc] initWithCVPixelBuffer:pixelBuffer options:@{}];
    VNDetectRectanglesRequest *request = [[VNDetectRectanglesRequest alloc] initWithCompletionHandler:VNRequestCompletionHandler];
    request.minimumAspectRatio = 0.1;
    request.maximumObservations = 0;
    [handler performRequests:@[request] error:nil];
}

// 物体跟踪
- (void)objectTrackWithPixelBuffer:(CVPixelBufferRef)pixelBuffer
{
    if (self.lastObsercationsDic.count == 0 ) {
        [self detectObjectWithPixelBuffer:pixelBuffer];
        return;
    }
    
    if (!self.sequenceHandler) {
        self.sequenceHandler = [[VNSequenceRequestHandler alloc] init];
    }
    
    NSArray<NSString *> *obsercationKeys = self.lastObsercationsDic.allKeys;
    
    NSMutableArray<VNTrackObjectRequest *> *obsercationRequest = [NSMutableArray array];
    
    size_t width = CVPixelBufferGetWidth(pixelBuffer);
    size_t height = CVPixelBufferGetHeight(pixelBuffer);
    CGSize size = CGSizeMake(width, height);
    
    CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();
    for (NSString *key in obsercationKeys) {
        
        VNDetectedObjectObservation *obsercation = self.lastObsercationsDic[key];
        
        VNTrackObjectRequest *trackObjectRequest = [[VNTrackObjectRequest alloc] initWithDetectedObjectObservation:obsercation completionHandler:^(VNRequest * _Nonnull request, NSError * _Nullable error) {
            
            CFAbsoluteTime end = CFAbsoluteTimeGetCurrent();
            NSLog(@"跟踪耗时： %f", end - start);
            
            if (nil == error && request.results.count > 0) {
                
                NSArray *results = request.results;
                VNDetectedObjectObservation *rectangleObservation = results.firstObject;
                if (rectangleObservation.confidence < 0.3) {
                    [self.lastObsercationsDic removeObjectForKey:rectangleObservation.uuid.UUIDString];
                    return;
                }
                
                [self.lastObsercationsDic setObject:rectangleObservation forKey:rectangleObservation.uuid.UUIDString];
                
                [self overlayImageWithSize:size];
                
                
            } else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    // 识别失败，移除物体跟踪队列
                    
                    [self.lastObsercationsDic removeObjectForKey:key];
                    [self overlayImageWithSize:size];
                    
                });
                
            }
        }];
        trackObjectRequest.trackingLevel = VNRequestTrackingLevelAccurate;
        
        [obsercationRequest addObject:trackObjectRequest];
    }
    
    
    NSError *error = nil;
    [self.sequenceHandler performRequests:obsercationRequest onCVPixelBuffer:pixelBuffer error:&error];
    
}


- (void)overlayImageWithSize:(CGSize)size
{
    
    NSDictionary *lastObsercationDicCopy = [NSDictionary dictionaryWithDictionary:self.lastObsercationsDic];
    NSArray *keyArr = [lastObsercationDicCopy allKeys];
    
    
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(size.width, size.height)];
    
    void (^UIGraphicsImageDrawingActions)(UIGraphicsImageRendererContext *rendererContext) = ^(UIGraphicsImageRendererContext *rendererContext)
    {
        CGAffineTransform  transform = CGAffineTransformIdentity;
        transform = CGAffineTransformScale(transform, size.width, -size.height);
        transform = CGAffineTransformTranslate(transform, 0, -1);
        
        for (NSString *uuid in keyArr) {
            VNDetectedObjectObservation *rectangleObservation = lastObsercationDicCopy[uuid];
            
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


@end

