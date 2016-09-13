//
//  FICImageTable.h
//  FastImageCache
//
//  Copyright (c) 2013 Path, Inc.
//  See LICENSE for full license agreement.
//

#import "FICImports.h"
#import "FICImageCache.h"
#import "FICEntity.h"

@class FICImageFormat;
@class FICImageTableChunk;
@class FICImageTableEntry;
@class FICImage;

NS_ASSUME_NONNULL_BEGIN

extern NSString *const FICImageTableEntryDataVersionKey;
extern NSString *const FICImageTableScreenScaleKey;

/**
 `FICImageTable` is the primary class that efficiently stores and retrieves cached image data. Image tables are defined by instances of `<FICImageFormat>`. Each image table is backed by a single
 file on disk that sequentially stores image entry data. All images in an image table are either opaque or not and have the same dimensions. Therefore, when defining your image formats, keep in
 mind that you cannot mix image dimensions or whether or not an image is opaque.
 */
@interface FICImageTable : NSObject

///-----------------------------
/// @name Image Table Properties
///-----------------------------

/**
 The file system path where the image table's data file is located.
 */
@property (nonatomic, copy, readonly) NSString *tableFilePath;

/**
 The file system path where the image table's metadata file is located.
 */
@property (nonatomic, copy, readonly) NSString *metadataFilePath;

/**
 The image format that describes the image table.
 */
@property (nonatomic, strong, readonly) FICImageFormat *imageFormat;

///-----------------------------------------------
/// @name Accessing Information about Image Tables
///-----------------------------------------------

/**
 Returns the page size for the current device.
 
 @return The number of bytes in a page of memory.
 
 @discussion This class method calls the UNIX function `getpagesize()` exactly once, storing the result in a static local variable.
 */
+ (int)pageSize;

/**
 Returns the file system path for the directory that stores image table files.
 
 @return The string representing the file system directory path where image table files are stored.
 
 @warning Image table files are stored in the user's caches directory, so you should be prepared for the image tables to be deleted from the file system at any time.
 */
+ (NSString *)directoryPath;

///----------------------------------
/// @name Initializing an Image Table
///----------------------------------

/**
 Initializes a new image table described by the provided image format.
 
 @param imageFormat The image format that describes the image table.
 
 @param imageCache The instance of `<FICImageCache>` that owns this image table.
 
 @return A new image table.
 
 @warning `FICImageTable` raises an exception if `imageFormat` is `nil`. `FICImageTable`'s implementation of `-init` simply calls through to this initializer, passing `nil` for `imageFormat`.
 */
- (nullable instancetype)initWithFormat:(FICImageFormat *)imageFormat imageCache:(FICImageCache *)imageCache NS_DESIGNATED_INITIALIZER;
-(instancetype) init __attribute__((unavailable("Invoke the designated initializer initWithFormat:imageCache: instead")));
+(instancetype) new __attribute__((unavailable("Invoke the designated initializer initWithFormat:imageCache: instead")));

///------------------------------------------------
/// @name Storing, Retrieving, and Deleting Entries
///------------------------------------------------

/**
 Stores new image entry data in the image table.
 
 @param entityUUID The UUID of the entity that uniquely identifies an image table entry. Must not be `nil`.
 
 @param sourceImageUUID The UUID of the source image that represents the actual image data stored in an image table entry. Must not be `nil`.
 
 @param imageDrawingBlock The drawing block provided by the entity that actually draws the source image into a bitmap context. Must not be `nil`.
 
 @discussion Objects conforming to `<FICEntity>` are responsible for providing an image drawing block that does the actual drawing of their source images to a bitmap context provided
 by the image table. Drawing in the provided bitmap context writes the uncompressed image data directly to the image table file on disk.
 
 @note If any of the parameters to this method are `nil`, this method does nothing.
 
 @see [FICEntity drawingBlockForImage:withFormatName:]
 */
- (void)setEntryForEntityUUID:(NSString *)entityUUID sourceImageUUID:(NSString *)sourceImageUUID imageDrawingBlock:(FICEntityImageDrawingBlock)imageDrawingBlock;

/**
 Returns a new image from the image entry data in the image table.
 
 @param entityUUID The UUID of the entity that uniquely identifies an image table entry. Must not be `nil`.
 
 @param sourceImageUUID The UUID of the source image that represents the actual image data stored in an image table entry. Must not be `nil`.
 
 @param preheatData A `BOOL` indicating whether or not the entry's image data should be preheated. See `<[FICImageTableEntry preheat]>` for more information.
 
 @return A new image created from the entry data stored in the image table or `nil` if something went wrong.
 
 @discussion The `UIImage` returned by this method is initialized by a `CGImageRef` backed directly by mapped file data, so no memory copy occurs.
 
 @note If either of the first two parameters to this method are `nil`, the return value is `nil`.
 
 @note If either the entity UUID or the source image UUID doesn't match the corresponding UUIDs in the entry data, then something has changed. The entry data is deleted for the
 provided entity UUID, and `nil` is returned.
 */
- (nullable UIImage *)newImageForEntityUUID:(NSString *)entityUUID sourceImageUUID:(NSString *)sourceImageUUID preheatData:(BOOL)preheatData;

/**
 Deletes image entry data in the image table.
 
 @param entityUUID The UUID of the entity that uniquely identifies an image table entry. Must not be `nil`.
 
 @note If `entityUUID` is `nil`, this method does nothing.
 */
- (void)deleteEntryForEntityUUID:(NSString *)entityUUID;

///-----------------------------------
/// @name Checking for Entry Existence
///-----------------------------------

/**
 Returns whether or not an entry exists in the image table.
 
 @param entityUUID The UUID of the entity that uniquely identifies an image table entry. Must not be `nil`.
 
 @param sourceImageUUID The UUID of the source image that represents the actual image data stored in an image table entry. Must not be `nil`.
 
 @return `YES` if an entry exists in the image table for the provided entity UUID and source image UUID. Otherwise, `NO`.
 
 @note If either of the parameters to this method are `nil`, the return value is `NO`.
 
 @note If either the entity UUID or the source image UUID doesn't match the corresponding UUIDs in the entry data, then something has changed. The entry data is deleted for the
 provided entity UUID, and `NO` is returned.
 */
- (BOOL)entryExistsForEntityUUID:(NSString *)entityUUID sourceImageUUID:(NSString *)sourceImageUUID;

///--------------------------------
/// @name Resetting the Image Table
///--------------------------------

/**
 Resets the image table by deleting all its data and metadata.
 */
- (void)reset;

@end

NS_ASSUME_NONNULL_END