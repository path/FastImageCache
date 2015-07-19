//
//  FICDAppDelegate.m
//  FastImageCacheDemo
//
//  Copyright (c) 2013 Path, Inc.
//  See LICENSE for full license agreement.
//

#import "FICDAppDelegate.h"
#import "FICImageCache.h"
#import "FICDViewController.h"
#import "FICDPhoto.h"

#pragma mark Class Extension

@interface FICDAppDelegate () <FICImageCacheDelegate>

@end

#pragma mark

@implementation FICDAppDelegate

#pragma mark - Application Lifecycle

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    NSMutableArray *mutableImageFormats = [NSMutableArray array];
    
    // Square image formats...
    NSInteger squareImageFormatMaximumCount = 400;
    FICImageFormatDevices squareImageFormatDevices = FICImageFormatDevicePhone | FICImageFormatDevicePad;
    
    // ...32-bit BGR
    FICImageFormat *squareImageFormat32BitBGRA = [FICImageFormat formatWithName:FICDPhotoSquareImage32BitBGRAFormatName family:FICDPhotoImageFormatFamily imageSize:FICDPhotoSquareImageSize style:FICImageFormatStyle32BitBGRA
        maximumCount:squareImageFormatMaximumCount devices:squareImageFormatDevices protectionMode:FICImageFormatProtectionModeNone];
    
    [mutableImageFormats addObject:squareImageFormat32BitBGRA];
    
    // ...32-bit BGR
    FICImageFormat *squareImageFormat32BitBGR = [FICImageFormat formatWithName:FICDPhotoSquareImage32BitBGRFormatName family:FICDPhotoImageFormatFamily imageSize:FICDPhotoSquareImageSize style:FICImageFormatStyle32BitBGR
        maximumCount:squareImageFormatMaximumCount devices:squareImageFormatDevices protectionMode:FICImageFormatProtectionModeNone];
    
    [mutableImageFormats addObject:squareImageFormat32BitBGR];
    
    // ...16-bit BGR
    FICImageFormat *squareImageFormat16BitBGR = [FICImageFormat formatWithName:FICDPhotoSquareImage16BitBGRFormatName family:FICDPhotoImageFormatFamily imageSize:FICDPhotoSquareImageSize style:FICImageFormatStyle16BitBGR
        maximumCount:squareImageFormatMaximumCount devices:squareImageFormatDevices protectionMode:FICImageFormatProtectionModeNone];
    
    [mutableImageFormats addObject:squareImageFormat16BitBGR];
    
    // ...8-bit Grayscale
    FICImageFormat *squareImageFormat8BitGrayscale = [FICImageFormat formatWithName:FICDPhotoSquareImage8BitGrayscaleFormatName family:FICDPhotoImageFormatFamily imageSize:FICDPhotoSquareImageSize style:FICImageFormatStyle8BitGrayscale
        maximumCount:squareImageFormatMaximumCount devices:squareImageFormatDevices protectionMode:FICImageFormatProtectionModeNone];
    
    [mutableImageFormats addObject:squareImageFormat8BitGrayscale];
    
    if ([UIViewController instancesRespondToSelector:@selector(preferredStatusBarStyle)]) {
        // Pixel image format
        NSInteger pixelImageFormatMaximumCount = 1000;
        FICImageFormatDevices pixelImageFormatDevices = FICImageFormatDevicePhone | FICImageFormatDevicePad;
        
        FICImageFormat *pixelImageFormat = [FICImageFormat formatWithName:FICDPhotoPixelImageFormatName family:FICDPhotoImageFormatFamily imageSize:FICDPhotoPixelImageSize style:FICImageFormatStyle32BitBGR
            maximumCount:pixelImageFormatMaximumCount devices:pixelImageFormatDevices protectionMode:FICImageFormatProtectionModeNone];
    
        [mutableImageFormats addObject:pixelImageFormat];
    }
    
    // Configure the image cache
    FICImageCache *sharedImageCache = [FICImageCache sharedImageCache];
    [sharedImageCache setDelegate:self];
    [sharedImageCache setFormats:mutableImageFormats];
    
    // Configure the window
    CGRect windowFrame = [[UIScreen mainScreen] bounds];
    UIWindow *window = [[UIWindow alloc] initWithFrame:windowFrame];
    [self setWindow:window];
    
    UIViewController *rootViewController = [[FICDViewController alloc] init];
    UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:rootViewController];
    
    [[self window] setRootViewController:navigationController];
    [[self window] makeKeyAndVisible];
    
    return YES;
}

#pragma mark - Protocol Implementations

#pragma mark - FICImageCacheDelegate

- (void)imageCache:(FICImageCache *)imageCache wantsSourceImageForEntity:(id<FICEntity>)entity withFormatName:(NSString *)formatName completionBlock:(FICImageRequestCompletionBlock)completionBlock {
    // Images typically come from the Internet rather than from the app bundle directly, so this would be the place to fire off a network request to download the image.
    // For the purposes of this demo app, we'll just access images stored locally on disk.
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        UIImage *sourceImage = [(FICDPhoto *)entity sourceImage];
        dispatch_async(dispatch_get_main_queue(), ^{
            completionBlock(sourceImage);
        });
    });
}

- (BOOL)imageCache:(FICImageCache *)imageCache shouldProcessAllFormatsInFamily:(NSString *)formatFamily forEntity:(id<FICEntity>)entity {
    return NO;
}

- (void)imageCache:(FICImageCache *)imageCache errorDidOccurWithMessage:(NSString *)errorMessage {
    NSLog(@"%@", errorMessage);
}

@end
