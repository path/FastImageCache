//
//  FICDFullscreenPhotoDisplayController.h
//  FastImageCacheDemo
//
//  Copyright (c) 2013 Path, Inc.
//  See LICENSE for full license agreement.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@class FICDPhoto;

@protocol FICDFullscreenPhotoDisplayControllerDelegate;

@interface FICDFullscreenPhotoDisplayController : NSObject

@property (nonatomic, weak) id <FICDFullscreenPhotoDisplayControllerDelegate> delegate;

+ (instancetype)sharedDisplayController;

@property (nonatomic, assign, readonly, getter = isDisplayingPhoto) BOOL displayingPhoto;

- (void)showFullscreenPhoto:(FICDPhoto *)photo forImageFormatName:(NSString *)imageFormatName withThumbnailImageView:(UIImageView *)thumbnailImageView;
- (void)hideFullscreenPhoto;

@end

@protocol FICDFullscreenPhotoDisplayControllerDelegate <NSObject>

@optional
- (void)photoDisplayController:(FICDFullscreenPhotoDisplayController *)photoDisplayController willShowSourceImage:(UIImage *)sourceImage forPhoto:(FICDPhoto *)photo withThumbnailImageView:(UIImageView *)thumbnailImageView;
- (void)photoDisplayController:(FICDFullscreenPhotoDisplayController *)photoDisplayController didShowSourceImage:(UIImage *)sourceImage forPhoto:(FICDPhoto *)photo withThumbnailImageView:(UIImageView *)thumbnailImageView;
- (void)photoDisplayController:(FICDFullscreenPhotoDisplayController *)photoDisplayController willHideSourceImage:(UIImage *)sourceImage forPhoto:(FICDPhoto *)photo withThumbnailImageView:(UIImageView *)thumbnailImageView;
- (void)photoDisplayController:(FICDFullscreenPhotoDisplayController *)photoDisplayController didHideSourceImage:(UIImage *)sourceImage forPhoto:(FICDPhoto *)photo withThumbnailImageView:(UIImageView *)thumbnailImageView;

@end
