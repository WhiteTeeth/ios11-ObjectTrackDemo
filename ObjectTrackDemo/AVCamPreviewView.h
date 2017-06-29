//
//  AVCamPreviewView.h
//  ObjectTrackDemo
//
//  Created by baiya on 2017/6/21.
//  Copyright © 2017年 Maxcw. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVCaptureSession.h>

@interface AVCamPreviewView : UIView

@property (nonatomic, readonly) AVCaptureVideoPreviewLayer *videoPreviewLayer;

@property (nonatomic) AVCaptureSession *session;

@end
