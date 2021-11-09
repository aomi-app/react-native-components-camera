//
//  SitbRCTCameraManager
//  SitbRCTCamera
//
//  Created by 田尘殇 on 16/6/24.
//  Copyright © 2016年 Sitb. All rights reserved.
//

#import "CameraManager.h"
#import "CameraView.h"
#import <Photos/PHAsset.h>
#import <Photos/PHImageManager.h>
#import <AssetsLibrary/ALAsset.h>


@interface CameraManager ()
@property(assign, nonatomic) NSInteger *flashMode;
@end

@implementation CameraManager

RCT_EXPORT_MODULE(AMCameraView)

- (id)init {
    if ((self = [super init])) {
        self.mirrorImage = false;
        self.sessionQueue = dispatch_queue_create("SitbCameraManagerQueue", DISPATCH_QUEUE_SERIAL);
        self.sampleBufferQueue = dispatch_queue_create("SitbCameraManagerSampleBufferQueue", DISPATCH_QUEUE_SERIAL);
        self.sendEventQueue = dispatch_queue_create("SitbCameraManagerSendEventQueue", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}


- (NSDictionary<NSString *, id> *)constantsToExport {

    NSMutableDictionary *runtimeBarcodeTypes = [NSMutableDictionary dictionary];
    [runtimeBarcodeTypes setDictionary:@{
            @"upce": AVMetadataObjectTypeUPCECode,
            @"code39": AVMetadataObjectTypeCode39Code,
            @"code39mod43": AVMetadataObjectTypeCode39Mod43Code,
            @"ean13": AVMetadataObjectTypeEAN13Code,
            @"ean8": AVMetadataObjectTypeEAN8Code,
            @"code93": AVMetadataObjectTypeCode93Code,
            @"code128": AVMetadataObjectTypeCode128Code,
            @"pdf417": AVMetadataObjectTypePDF417Code,
            @"qr": AVMetadataObjectTypeQRCode,
            @"aztec": AVMetadataObjectTypeAztecCode,
            @"interleaved2of5": AVMetadataObjectTypeInterleaved2of5Code,
            @"itf14": AVMetadataObjectTypeITF14Code,
            @"dataMatrix": AVMetadataObjectTypeDataMatrixCode
    }];

    return @{
            @"CameraFacing": @{
                    @"back": @(AVCaptureDevicePositionBack),
                    @"front": @(AVCaptureDevicePositionFront)
            },
            @"Orientation": @{
                    @"auto": @(0),
                    @"landscapeLeft": @(AVCaptureVideoOrientationLandscapeLeft),
                    @"landscapeRight": @(AVCaptureVideoOrientationLandscapeRight),
                    @"portrait": @(AVCaptureVideoOrientationPortrait),
                    @"portraitUpsideDown": @(AVCaptureVideoOrientationPortraitUpsideDown)
            },
            @"Quality": @{
                    @"high": AVCaptureSessionPresetHigh,
                    @"medium": AVCaptureSessionPresetMedium,
                    @"low": AVCaptureSessionPresetLow,
                    @"vga": AVCaptureSessionPreset640x480,
                    @"hd720": AVCaptureSessionPreset1280x720,
                    @"hd1080": AVCaptureSessionPreset1920x1080,
                    @"photo": AVCaptureSessionPresetPhoto
            },
            @"BarCodeType": runtimeBarcodeTypes
    };
}

+ (BOOL)requiresMainQueueSetup {
    return NO;
}


/******************** Component PropTypes **********************/
// 前置相机或者后置相机
RCT_EXPORT_VIEW_PROPERTY(cameraFacing, NSInteger);

// 相机方向
RCT_EXPORT_VIEW_PROPERTY(orientation, NSInteger);

// 当获取摄像头数据
RCT_EXPORT_VIEW_PROPERTY(onCaptureOutputBuffer, RCTBubblingEventBlock);

// 当获取二维码数据
RCT_EXPORT_VIEW_PROPERTY(onBarCodeRead, RCTBubblingEventBlock);

// 质量
RCT_CUSTOM_VIEW_PROPERTY(quality, NSString, CameraView) {
    NSString *quality = [RCTConvert NSString:json];
    [self setCaptureQuality:quality];
}

RCT_CUSTOM_VIEW_PROPERTY(barCodeTypes, NSArray, CameraView) {
    self.barCodeTypes = [RCTConvert NSArray:json];
}

/******************** Component Method **********************/
/**
 * 检查是否有相机权限
 */
RCT_EXPORT_METHOD(
            checkVideoAuthorizationStatus:
            (RCTPromiseResolveBlock) resolve
            reject:
            (__unused
        RCTPromiseRejectBlock)reject) {
    __block NSString *mediaType = AVMediaTypeVideo;

    [AVCaptureDevice requestAccessForMediaType:mediaType completionHandler:^(BOOL granted) {
        resolve(@(granted));
    }];
}

/**
 * 检查是否有麦克风权限
 */
RCT_EXPORT_METHOD(checkAudioAuthorizationStatus:
    (RCTPromiseResolveBlock) resolve
            reject:
            (__unused
        RCTPromiseRejectBlock)reject) {
    __block NSString *mediaType = AVMediaTypeAudio;

    [AVCaptureDevice requestAccessForMediaType:mediaType completionHandler:^(BOOL granted) {
        resolve(@(granted));
    }];
}

RCT_EXPORT_METHOD(
            scanImage:
            (NSDictionary *) data
            resolve:
            (RCTPromiseResolveBlock) resolve
            reject:
            (__unused
        RCTPromiseRejectBlock)reject) {
    NSString *path = data[@"path"];
    NSURL *url = [NSURL URLWithString:path];

    PHFetchResult *fetchResult = [PHAsset fetchAssetsWithALAssetURLs:@[url] options:nil];
    PHAsset *asset = fetchResult.firstObject;

    PHImageManager *manager = [PHImageManager defaultManager];
    [manager requestImageDataForAsset:asset options:nil resultHandler:^(NSData *_Nullable imageData,
            NSString *_Nullable dataUTI, UIImageOrientation orientation, NSDictionary *_Nullable info) {
        CIImage *ciImage = [CIImage imageWithData:imageData];
        CIDetector *detector = [CIDetector detectorOfType:CIDetectorTypeQRCode context:nil options:@{CIDetectorAccuracy: CIDetectorAccuracyLow}];
        NSArray *feature = [detector featuresInImage:ciImage];
        for (CIQRCodeFeature *result in feature) {
            resolve(@{
                    @"format": AVMetadataObjectTypeQRCode,
                    @"text": result.messageString
            });
        }
    }];

}

/**
 * 初始化 AVCaptureSession
 * 初始化AVCaptureDeviceInput
 * @return js View视图
 */
- (UIView *)view {
    self.presetCamera = AVCaptureDevicePositionBack;
    self.session = [AVCaptureSession new];
    self.previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.session];
    if (!self.cameraView) {
        self.cameraView = [[CameraView alloc] initWithManager:self bridge:self.bridge];
    }
    return self.cameraView;
}

/**
 * 初始化 CaptureSessionInput
 * @param type 相机类型
 */
- (void)initializeCaptureSessionInput:(NSString *)type {
    dispatch_async(self.sessionQueue, ^{
        if (type == AVMediaTypeAudio) {
            for (AVCaptureDeviceInput *input in [self.session inputs]) {
                if ([input.device hasMediaType:AVMediaTypeAudio]) {
                    // If an audio input has been configured we don't need to set it up again
                    return;
                }
            }
        }

        NSError *error = nil;
        AVCaptureDevice *captureDevice;

        if (type == AVMediaTypeAudio) {
            captureDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
        } else if (type == AVMediaTypeVideo) {
            captureDevice = [self deviceWithMediaType:AVMediaTypeVideo preferringPosition:(AVCaptureDevicePosition) self.presetCamera];
        }

        if (captureDevice == nil) {
            RCTLogWarn(@"没有发现可用的设备.");
            return;
        }

        AVCaptureDeviceInput *captureDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:captureDevice error:&error];

        if (error || captureDeviceInput == nil) {
            RCTLogWarn(@"%@", error);
            return;
        }

        [self.session beginConfiguration];

        if (type == AVMediaTypeVideo) {
            [self.session removeInput:self.videoCaptureDeviceInput];
        }

        if ([self.session canAddInput:captureDeviceInput]) {
            [self.session addInput:captureDeviceInput];

            if (type == AVMediaTypeAudio) {
                self.audioCaptureDeviceInput = captureDeviceInput;
            } else if (type == AVMediaTypeVideo) {
                self.videoCaptureDeviceInput = captureDeviceInput;
                [self setFlashMode];
            }
        }

        [self.session commitConfiguration];
    });
};

/**
 * 启动session
 */
- (void)startSession {
    dispatch_async(self.sessionQueue, ^{
        if (self.presetCamera == AVCaptureDevicePositionUnspecified) {
            self.presetCamera = AVCaptureDevicePositionBack;
        }

        AVCaptureVideoDataOutput *videoDataOutput = [[AVCaptureVideoDataOutput alloc] init];
        if ([self.session canAddOutput:videoDataOutput]) {
            [videoDataOutput setSampleBufferDelegate:self queue:self.sampleBufferQueue];
            [videoDataOutput setVideoSettings:@{(id) kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA)}];

            [self.session addOutput:videoDataOutput];
        }

//        AVCapturePhotoOutput *photoOutput = [[AVCapturePhotoOutput alloc] init];
//        if ([self.session canAddOutput:photoOutput]) {
//            AVCapturePhotoSettings *photoSettings = [[AVCapturePhotoSettings alloc] init];
//            [photoOutput capturePhotoWithSettings:photoSettings delegate:self];
//            [self.session addOutput:photoOutput];
//
//            self.photoOutput = photoOutput;
//            self.photoSettings = photoSettings;
//        }

        AVCaptureMetadataOutput *metadataOutput = [[AVCaptureMetadataOutput alloc] init];
        if ([self.session canAddOutput:metadataOutput]) {
            [metadataOutput setMetadataObjectsDelegate:self queue:self.sessionQueue];
            [self.session addOutput:metadataOutput];
            [metadataOutput setMetadataObjectTypes:self.barCodeTypes];
        }

        __weak CameraManager *weakSelf = self;
        [self setRuntimeErrorHandlingObserver:[NSNotificationCenter.defaultCenter
                addObserverForName:AVCaptureSessionRuntimeErrorNotification
                            object:self.session
                             queue:nil
                        usingBlock:^(NSNotification *note) {
                            CameraManager *strongSelf = weakSelf;
                            dispatch_async(strongSelf.sessionQueue, ^{
                                // Manually restarting the session since it must have been stopped due to an error.
                                [strongSelf.session startRunning];
                            });
                        }]
        ];

        [self.session startRunning];
    });
}

/**
 * stop session
 */
- (void)stopSession {
    dispatch_async(self.sessionQueue, ^{
        self.cameraView = nil;
        [self.previewLayer removeFromSuperlayer];
        [self.session commitConfiguration];
        [self.session stopRunning];
        for (AVCaptureInput *input in self.session.inputs) {
            [self.session removeInput:input];
        }

        for (AVCaptureOutput *output in self.session.outputs) {
            [self.session removeOutput:output];
        }
    });
}

- (void)stopCapture {

}

/**
 * 实时捕获读取的图像信息
 */
- (void)captureOutput:(AVCaptureOutput *)captureOutput
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection {

    if (self.onCaptureOutputBuffer) {
        // 为媒体数据设置一个CMSampleBuffer的Core Video图像缓存对象
        CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
        // 锁定pixel buffer的基地址
        CVPixelBufferLockBaseAddress(imageBuffer, (CVPixelBufferLockFlags) 0);
        // 得到pixel buffer的基地址
        void *baseAddress = CVPixelBufferGetBaseAddress(imageBuffer);
        // 得到pixel buffer的行字节数
        size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
        // 得到pixel buffer的宽和高
        size_t width = CVPixelBufferGetWidth(imageBuffer);
        size_t height = CVPixelBufferGetHeight(imageBuffer);
        // 创建一个依赖于设备的RGB颜色空间
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        // 用抽样缓存的数据创建一个位图格式的图形上下文（graphics context）对象
        CGContextRef context = CGBitmapContextCreate(baseAddress, width, height, 8, bytesPerRow, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
        // 根据这个位图context中的像素数据创建一个Quartz image对象
        CGImageRef quartzImage = CGBitmapContextCreateImage(context);
        // 解锁pixel buffer
        CVPixelBufferUnlockBaseAddress(imageBuffer, (CVPixelBufferLockFlags) 0);
        // 释放context和颜色空间
        CGContextRelease(context);
        CGColorSpaceRelease(colorSpace);
        // 用Quartz image创建一个UIImage对象image
        UIImage *image = [UIImage imageWithCGImage:quartzImage];
        // 释放Quartz image对象
        CGImageRelease(quartzImage);

        NSString *encodedString = [UIImagePNGRepresentation(image) base64EncodedStringWithOptions:NSDataBase64Encoding64CharacterLineLength];
        dispatch_async(self.sendEventQueue, ^{
            self.onCaptureOutputBuffer(@{@"buffer": encodedString});
        });
    }
}

- (void)   captureOutput:(AVCaptureOutput *)captureOutput
didOutputMetadataObjects:(NSArray *)metadataObjects
          fromConnection:(AVCaptureConnection *)connection {
    if (!self.onBarCodeRead) {
        return;
    }
    AVMetadataMachineReadableCodeObject *metadata = [metadataObjects lastObject];

    for (id barcodeType in self.barCodeTypes) {
        if ([metadata.type isEqualToString:barcodeType]) {
            // Transform the meta-data coordinates to screen coords
            AVMetadataMachineReadableCodeObject *transformed = (AVMetadataMachineReadableCodeObject *) [_previewLayer transformedMetadataObjectForMetadataObject:metadata];

            NSDictionary *event = @{
                    @"format": metadata.type,
                    @"text": metadata.stringValue,
                    @"bounds": @{
                            @"origin": @{
                                    @"x": [NSString stringWithFormat:@"%f", transformed.bounds.origin.x],
                                    @"y": [NSString stringWithFormat:@"%f", transformed.bounds.origin.y]
                            },
                            @"size": @{
                                    @"height": [NSString stringWithFormat:@"%f", transformed.bounds.size.height],
                                    @"width": [NSString stringWithFormat:@"%f", transformed.bounds.size.width],
                            }
                    }
            };
            [self stopSession];
            dispatch_async(self.sendEventQueue, ^{
                self.onBarCodeRead(event);
            });
        }

    }

}


- (AVCaptureDevice *)deviceWithMediaType:(NSString *)mediaType preferringPosition:(AVCaptureDevicePosition)position {
    AVCaptureDevice *captureDevice;
    if ([[UIDevice currentDevice].systemVersion floatValue] >= 10.0) {
        AVCaptureDeviceDiscoverySession *discoverySession = [
                AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:@[AVCaptureDeviceTypeBuiltInWideAngleCamera]
                                                                      mediaType:mediaType
                                                                       position:position
        ];
        NSArray *devices = discoverySession.devices;
        captureDevice = [devices firstObject];
        for (AVCaptureDevice *device in devices) {
            if ([device position] == position) {
                captureDevice = device;
                break;
            }
        }
    } else {
        NSArray *devices = [AVCaptureDevice devicesWithMediaType:mediaType];
        for (AVCaptureDevice *camera in devices) {
            if (camera.position == position) {
                captureDevice = camera;
                break;
            }
        }
    }
    return captureDevice;
}

- (void)setFlashMode {
    AVCaptureDevice *device = [self.videoCaptureDeviceInput device];
    NSError *error = nil;

    if (![device hasFlash]) return;
    if (![device lockForConfiguration:&error]) {
        NSLog(@"%@", error);
        return;
    }
    if (device.hasFlash && [device isFlashModeSupported:self.flashMode]) {
        NSError *error = nil;
        if ([device lockForConfiguration:&error]) {
            [device setFlashMode:self.flashMode];
            [device unlockForConfiguration];
        } else {
            NSLog(@"%@", error);
        }
    }
    [device unlockForConfiguration];
}


/**
 * 设置图片质量
 * @param quality 图片质量
 */
- (void)setCaptureQuality:(NSString *)quality {
    if (quality) {
        [self.session beginConfiguration];
        if ([self.session canSetSessionPreset:quality]) {
            self.session.sessionPreset = quality;
        }
        [self.session commitConfiguration];
    }
}

@end
