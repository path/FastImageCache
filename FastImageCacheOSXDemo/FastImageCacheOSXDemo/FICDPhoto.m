//
//  FICDPhoto.m
//  FastImageCacheDemo
//
//  Copyright (c) 2013 Path, Inc.
//  See LICENSE for full license agreement.
//

#import "FICDPhoto.h"
#import "FICUtilities.h"

#pragma mark External Definitions

NSString *const FICDPhotoImageFormatFamily = @"FICDPhotoImageFormatFamily";

NSString *const FICDPhotoSquareImage32BitBGRAFormatName = @"com.path.FastImageCacheDemo.FICDPhotoSquareImage32BitBGRAFormatName";
NSString *const FICDPhotoSquareImage32BitBGRFormatName = @"com.path.FastImageCacheDemo.FICDPhotoSquareImage32BitBGRFormatName";
NSString *const FICDPhotoSquareImage16BitBGRFormatName = @"com.path.FastImageCacheDemo.FICDPhotoSquareImage16BitBGRFormatName";
NSString *const FICDPhotoSquareImage8BitGrayscaleFormatName = @"com.path.FastImageCacheDemo.FICDPhotoSquareImage8BitGrayscaleFormatName";
NSString *const FICDPhotoPixelImageFormatName = @"com.path.FastImageCacheDemo.FICDPhotoPixelImageFormatName";

CGSize const FICDPhotoSquareImageSize = {75, 75};
CGSize const FICDPhotoPixelImageSize = {1, 1};

#pragma mark - Class Extension

@interface FICDPhoto () {
    NSString *_UUID;
}

@end

#pragma mark

@implementation FICDPhoto


#pragma mark - FICImageCacheEntity

- (NSString *)UUID {
    if (_UUID == nil) {
        // MD5 hashing is expensive enough that we only want to do it once
        NSString *imageName = [_sourceImageURL lastPathComponent];
        CFUUIDBytes UUIDBytes = FICUUIDBytesFromMD5HashOfString(imageName);
        _UUID = FICStringWithUUIDBytes(UUIDBytes);
    }
    
    return _UUID;
}

- (NSString *)sourceImageUUID {
    return [self UUID];
}

- (NSURL *)sourceImageURLWithFormatName:(NSString *)formatName {
    return _sourceImageURL;
}

- (FICEntityImageDrawingBlock)drawingBlockForImage:(NSImage *)image withFormatName:(NSString *)formatName;
{
    
    FICEntityImageDrawingBlock drawingBlock = ^(CGContextRef context, CGSize contextSize) {
        CGRect contextBounds = CGRectZero;
        contextBounds.size = contextSize;
        CGContextClearRect(context, contextBounds);
        NSGraphicsContext *ctx = [NSGraphicsContext graphicsContextWithGraphicsPort:context flipped:YES];
        [NSGraphicsContext saveGraphicsState];
        [NSGraphicsContext setCurrentContext:ctx];
        [image drawInRect:contextBounds];
        [NSGraphicsContext restoreGraphicsState];
    };
    
    return drawingBlock;
}

@end
