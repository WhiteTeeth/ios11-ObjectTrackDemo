//
//  AVCamPreviewView.m
//  ObjectTrackDemo
//
//  Created by baiya on 2017/6/21.
//  Copyright © 2017年 Maxcw. All rights reserved.
//

#import "AVCamPreviewView.h"
#import <AVFoundation/AVFoundation.h>

@implementation AVCamPreviewView


+ (Class)layerClass
{
    return [AVCaptureVideoPreviewLayer class];
}

- (AVCaptureVideoPreviewLayer *)videoPreviewLayer
{
    return (AVCaptureVideoPreviewLayer *)self.layer;
}

- (AVCaptureSession *)session
{
    return self.videoPreviewLayer.session;
}

- (void)setSession:(AVCaptureSession *)session
{
    self.videoPreviewLayer.session = session;
}


@end
