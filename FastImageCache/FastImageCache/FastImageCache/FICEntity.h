//
//  FICEntity.h
//  FastImageCache
//
//  Copyright (c) 2013 Path, Inc.
//  See LICENSE for full license agreement.
//

#import "FICImports.h"
@class FICImageFormat;

NS_ASSUME_NONNULL_BEGIN

typedef void (^FICEntityImageDrawingBlock)(CGContextRef context, CGSize contextSize);

/**
 `FICEntity` is a protocol that classes interacting with the image cache must conform to. An entity uniquely identifies entries in image tables, which are instances of `<FICImageTable>`.
 */
@protocol FICEntity <NSObject>

@required

/**
 A string that uniquely identifies this entity.
 
 @discussion Within each image table, each entry is identified by an entity's UUID. Ideally, this value should never change for an entity. For example, if your entity class is a person
 model, its UUID might be an API-assigned, unchanging, unique user ID. No matter how the properties of the person change, its user ID should never change.
 */
@property (nonatomic, copy, readonly) NSString *fic_UUID;

/**
 A string that uniquely identifies an entity's source image.
 
 @discussion While `<UUID>` should be unchanging, a source image UUID might change. For example, if your entity class is a person model, its source image UUID might change every time the
 person changes their profile photo. In this case, the source image UUID might be a hash of the profile photo URL (assuming each image is given a unique URL).
 */
@property (nonatomic, copy, readonly) NSString *fic_sourceImageUUID;

/**
 Returns the source image URL associated with a specific format name.
 
 @param formatName The name of the image format that identifies which image table is requesting the source image.
 
 @return A URL representing the requested source image.
 
 @discussion Fast Image Cache operates on URLs when requesting source images. Typically, these URLs will point to remote image resources that must be downloaded from the Internet. While the
 URL returned by this method must be a valid instance of `NSURL`, it does not need to point to an actual remote resource. The URL might point to a file path on disk or be composed of a custom
 URL scheme of your choosing. The image cache's delegate is prompted to provide a source image for a particular entity and format name when it cannot find the requested image. It only uses the
 URL returned by this method to key image cache requests. No network or file operations are performed by the image cache.
 
 An example of when this method might return different source image URLs for the same entity is if you have defined several image formats for different thumbnail sizes and styles. For very
 large thumbnails, the source image URL might be the original image. For smaller thumbnails, the source image URL might point to a downscaled version of the original image.
 
 @see FICImageFormat
 @see [FICImageCacheDelegate imageCache:wantsSourceImageForEntity:withFormatName:completionBlock:]
 */
- (nullable NSURL *)fic_sourceImageURLWithFormatName:(NSString *)formatName;


/**
 Returns the drawing block for a specific image and format name.
 
 @param image The cached image that represents this entity.
 
 @param formatName The name of the image format that identifies which image table is requesting the source image.
 
 @return The drawing block used to draw the image data to be stored in the image table.
 
 The drawing block's type is defined as follows:
 
     typedef void (^FICEntityImageDrawingBlock)(CGContextRef context, CGSize contextSize)
 
 @discussion Each entity is responsible for drawing its own source image into the bitmap context provided by the image table that will store the image data. Often it is sufficient to simply
 draw the image into the bitmap context. However, if you wish to apply any additional graphics processing to the source image before it is stored (such as clipping the image to a roundect rect),
 you may use this block to do so.
 
 @note This block will always be called from the serial dispatch queue used by the image cache.
 */
- (nullable FICEntityImageDrawingBlock)fic_drawingBlockForImage:(UIImage *)image withFormatName:(NSString *)formatName;

@optional
/**
 Returns the image for a format
 
 @param format The image format that identifies which image table is requesting the source image.
 */
- (nullable UIImage *)fic_imageForFormat:(FICImageFormat *)format;

@end

NS_ASSUME_NONNULL_END