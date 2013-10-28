//
//  FICDPhoto.h
//  FastImageCacheDemo
//
//  Copyright (c) 2013 Path, Inc.
//  See LICENSE for full license agreement.
//

#import "FICEntity.h"

extern NSString *const FICDPhotoImageFormatFamily;

extern NSString *const FICDPhotoSquareImage32BitBGRAFormatName;
extern NSString *const FICDPhotoSquareImage32BitBGRFormatName;
extern NSString *const FICDPhotoSquareImage16BitBGRFormatName;
extern NSString *const FICDPhotoSquareImage8BitGrayscaleFormatName;
extern NSString *const FICDPhotoPixelImageFormatName;

extern CGSize const FICDPhotoSquareImageSize;
extern CGSize const FICDPhotoPixelImageSize;

@interface FICDPhoto : NSObject <FICEntity>

@property (nonatomic, copy) NSURL *sourceImageURL;
@property (nonatomic, strong, readonly) UIImage *sourceImage;
@property (nonatomic, strong, readonly) UIImage *thumbnailImage;
@property (nonatomic, assign, readonly) BOOL thumbnailImageExists;

// Methods for demonstrating more conventional caching techniques
- (void)generateThumbnail;
- (void)deleteThumbnail;

@end
