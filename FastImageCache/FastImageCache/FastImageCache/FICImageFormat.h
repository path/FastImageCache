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

typedef NS_ENUM(NSUInteger, FICImageFormatStyle) {
    FICImageFormatStyle32BitBGRA,
    FICImageFormatStyle32BitBGR,
    FICImageFormatStyle16BitBGR,
    FICImageFormatStyle8BitGrayscale,
};

typedef NS_ENUM(NSUInteger, FICImageFormatProtectionMode) {
    FICImageFormatProtectionModeNone,
    FICImageFormatProtectionModeComplete,
    FICImageFormatProtectionModeCompleteUntilFirstUserAuthentication,
};

/**
 `FICImageFormat` acts as a definition for the types of images that are stored in the image cache. Each image format must have a unique name, but multiple formats can belong to the same family.
 All images associated with a particular format must have the same image dimentions and opacity preference. You can define the maximum number of entries that an image format can accommodate to
 prevent the image cache from consuming too much disk space. Each `<FICImageTable>` managed by the image cache is associated with a single image format.
 */

NS_ASSUME_NONNULL_BEGIN
@interface FICImageFormat : NSObject <NSCopying>

///------------------------------
/// @name Image Format Properties
///------------------------------

/**
 The name of the image format. Each image format must have a unique name.
 
 @note Since multiple instances of Fast Image Cache can exist in the same application, it is important that image format name's be unique across all instances of `<FICImageCache>`. Reverse DNS naming
 is recommended (e.g., com.path.PTUserProfilePhotoLargeImageFormat).
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
 A bitmask of type `<FICImageFormatStyle>` that defines the style of the image format.
 
 `FICImageFormatStyle` has the following values:
 
 - `FICImageFormatStyle32BitBGRA`: Full-color image format with alpha channel. 8 bits per color component, and 8 bits for the alpha channel.
 - `FICImageFormatStyle32BitBGR`: Full-color image format with no alpha channel. 8 bits per color component. The remaining 8 bits are unused.
 - `FICImageFormatStyle16BitBGR`: Reduced-color image format with no alpha channel. 5 bits per color component. The remaining bit is unused.
 - `FICImageFormatStyle8BitGrayscale`: Grayscale-only image format with no alpha channel.
 
 If you are storing images without an alpha component (e.g., JPEG images), then you should use the `FICImageFormatStyle32BitBGR` style for performance reasons. If you are storing very small images or images
 without a great deal of color complexity, the `FICImageFormatStyle16BitBGR` style may be sufficient and uses less disk space than the 32-bit styles use. For grayscale-only image formats, the
 `FICImageFormatStyle8BitGrayscale` style is sufficient and further reduces disk space usage.
 */
@property (nonatomic, assign)  FICImageFormatStyle style;

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
 The size, in pixels, of the images stored in the image table created by this format. This takes into account the screen scale.
 */
@property (nonatomic, assign, readonly) CGSize pixelSize;

/**
 The bitmap info associated with the images created with this image format.
 */
@property (nonatomic, assign, readonly) CGBitmapInfo bitmapInfo;

/**
 The number of bytes each pixel of an image created with this image format occupies.
 */
@property (nonatomic, assign, readonly) NSInteger bytesPerPixel;

/**
 The number of bits each pixel component (e.g., blue, green, red color channels) uses for images created with this image format.
 */
@property (nonatomic, assign, readonly) NSInteger bitsPerComponent;

/**
 Whether or not the the images represented by this image format are grayscale.
 */
@property (nonatomic, assign, readonly) BOOL isGrayscale;

/**
 The data protection mode that image table files will be created with.
 
 `FICImageFormatProtectionMode` has the following values:
 
 - `FICImageFormatProtectionModeNone`: No data protection is used. The image table file backing this image format will always be available for reading and writing.
 - `FICImageFormatProtectionModeComplete`: Complete data protection is used. As soon as the system enables data protection (i.e., when the device is locked), the image table file backing this image
 format will not be available for reading and writing. As a result, images of this format should not be requested by Fast Image Cache when executing backgrounded code.
 - `FICImageFormatProtectionModeCompleteUntilFirstUserAuthentication`: Partial data protection is used. After a device restart, until the user unlocks the device for the first time, complete data
 protection is in effect. However, after the device has been unlocked for the first time, the image table file backing this image format will remain available for readin and writing. This mode may be
 a good compromise between encrypting image table files after the device powers down and allowing the files to be accessed successfully by Fast Image Cache, whether or not the device is subsequently
 locked.
 
 @note Data protection can prevent Fast Image Cache from accessing its image table files to read and write image data. If the image data being stored in Fast Image Cache is not sensitive in nature,
 consider using `FICImageFormatProtectionModeNone` to prevent any issues accessing image table files when the disk is encrypted.
 */
@property (nonatomic, assign) FICImageFormatProtectionMode protectionMode;

/**
 The string representation of `<protectionMode>`.
 */
@property (nonatomic, assign, readonly) NSString *protectionModeString;

/**
 The dictionary representation of this image format.
 
 @discussion Fast Image Cache automatically serializes the image formats that it uses to disk. If an image format ever changes, Fast Image Cache automatically detects the change and invalidates the
 image table associated with that image format. The image table is then recreated from the updated image format.
 */
@property (nonatomic, copy, readonly) NSDictionary<NSString*, id> *dictionaryRepresentation;

///-----------------------------------
/// @name Initializing an Image Format
///-----------------------------------

/**
 Convenience initializer to create a new image format.
 
 @param name The name of the image format. Each image format must have a unique name.
 
 @param family The optional family that the image format belongs to. See the `<family>` property description for more information.
 
 @param imageSize The size, in points, of the images stored in the image table created by this format.
 
 @param style The style of the image format. See the `<style>` property description for more information.
 
 @param maximumCount The maximum number of entries that an image table can contain for this image format.
 
 @param devices A bitmask of type `<FICImageFormatDevices>` that defines which devices are managed by an image table.
 
 @param protectionMode The data protection mode to use when creating the backing image table file for this image format. See the `<protectionMode>` property description for more information.
 
 @return An autoreleased instance of `FICImageFormat` or one of its subclasses, if any exist.
 */
+ (instancetype)formatWithName:(NSString *)name family:(NSString *)family imageSize:(CGSize)imageSize style:(FICImageFormatStyle)style maximumCount:(NSInteger)maximumCount devices:(FICImageFormatDevices)devices protectionMode:(FICImageFormatProtectionMode)protectionMode;

@end
NS_ASSUME_NONNULL_END