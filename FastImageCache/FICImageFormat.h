//
//  FICImageFormat.h
//  FastImageCache
//
//  Copyright (c) 2013 Path, Inc.
//  See LICENSE for full license agreement.
//

#import "FICImports.h"

@class FICImageTable;

typedef NS_OPTIONS(NSUInteger, FICImageFormatDevices) {
    FICImageFormatDevicePhone = 1 << UIUserInterfaceIdiomPhone,
    FICImageFormatDevicePad = 1 << UIUserInterfaceIdiomPad,
};

/**
 `FICImageFormat` acts as a definition for the types of images that are stored in the image cache. Each image format must have a unique name, but multiple formats can belong to the same family.
 All images associated with a particular format must have the same image dimentions and opacity preference. You can define the maximum number of entries that an image format can accommodate to
 prevent the image cache from consuming too much disk space. Each `<FICImageTable>` managed by the image cache is associated with a single image format.
 */


typedef NS_OPTIONS(NSUInteger, FICImageFormatStyle) {
    FICImageFormatStyle32BitBGRA,
    FICImageFormatStyle32BitBGR,
    FICImageFormatStyle16BitBGR,
    FICImageFormatStyle8BitGrayscale,
};

@interface FICImageFormat : NSObject <NSCopying>

///------------------------------
/// @name Image Format Properties
///------------------------------

/**
 The name of the image format. Each image format must have a unique name.
 */
@property (nonatomic, copy) NSString *name;

/**
 The optional family that the image format belongs to. Families group together related image formats.
 
 @discussion If you are using the image cache to create several different cached variants of the same source image, all of those variants would be unique image formats that share the same family.
 
 For example, you might define a `userPhoto` family that groups together image formats with the following names: `userPhotoSmallThumbnail`, `userPhotoLargeThumbnail`, `userPhotoLargeThumbnailBorder`.
 Ideally, the same source image can be processed to create cached image data for every image format belonging to the same family.
 
 `<FICImageCache>` provides its delegate a chance to process all image formats in a given family at the same time when a particular entity-image format pair is being processed. This allows you to process
 a source image once instead of having to download and process the same source image multiple times for different formats in the same family.
 
 @see [FICImageCacheDelegate imageCache:shouldProcessAllFormatsInFamily:forEntity:]
 */
@property (nonatomic, copy) NSString *family;

/**
 The size, in points, of the images stored in the image table created by this format.
 */
@property (nonatomic, assign) CGSize imageSize;

/**
 The size, in pixels, of the images stored in the image table created by this format. This takes into account the screen scale.
 */
@property (nonatomic, assign, readonly) CGSize pixelSize;

@property (nonatomic, assign)  FICImageFormatStyle style;

@property (nonatomic, readonly) CGBitmapInfo bitmapInfo;
@property (nonatomic, readonly) NSInteger bytesPerPixel;
@property (nonatomic, readonly) NSInteger bitsPerComponent;
@property (nonatomic, readonly) BOOL isGrayscale;

/**
 The maximum number of entries that an image table can contain for this image format.
 
 @discussion Images inserted into the image table defined by this image format after the maximum number of entries has been exceeded will replace the least-recently accessed entry.
 */
@property (nonatomic, assign) NSInteger maximumCount;

/**
 A bitmask of type `<FICImageFormatDevices>` that defines which devices are managed by an image table.
 
 @discussion If the current device is not included in a particular image format, the image cache will not store image data for that device.
 */
@property (nonatomic, assign) FICImageFormatDevices devices;

/**
 The dictionary representation of this image format.
 
 @discussion Fast Image Cache automatically serializes the image formats that it uses to disk. If an image format ever changes, Fast Image Cache automatically detects the change and invalidates the image table associated with that image format. The image table is then recreated from the updated image format.
 */
@property (nonatomic, copy, readonly) NSDictionary *dictionaryRepresentation;

///-----------------------------------
/// @name Initializing an Image Format
///-----------------------------------

/**
 Convenience initializer to create a new image format.
 
 @param name The name of the image format. Each image format must have a unique name.
 
 @param family The optional family that the image format belongs to. See the `<family>` property description for more information.
 
 @param imageSize The size, in points, of the images stored in the image table created by this format.
 
 @param isOpaque Whether or not the image table's backing bitmap data provider is opaque.
 
 @param maximumCount The maximum number of entries that an image table can contain for this image format.
 
 @param devices A bitmask of type `<FICImageFormatDevices>` that defines which devices are managed by an image table.
 
 @return An autoreleased instance of `<FICImageFormat>` or one of its subclasses, if any exist.
 */
+ (instancetype)formatWithName:(NSString *)name family:(NSString *)family imageSize:(CGSize)imageSize style:(FICImageFormatStyle)style maximumCount:(NSInteger)maximumCount devices:(FICImageFormatDevices)devices;

@end
