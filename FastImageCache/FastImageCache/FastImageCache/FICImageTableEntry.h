//
//  FICImageTableEntry.h
//  FastImageCache
//
//  Copyright (c) 2013 Path, Inc.
//  See LICENSE for full license agreement.
//

#import "FICImports.h"

NS_ASSUME_NONNULL_BEGIN

@class FICImageTableChunk;
@class FICImageCache;

typedef struct {
    CFUUIDBytes _entityUUIDBytes;
    CFUUIDBytes _sourceImageUUIDBytes;
} FICImageTableEntryMetadata;

/**
 `FICImageTableEntry` represents an entry in an image table. It contains the necessary data and metadata to store a single entry of image data. Entries are created from instances of
 `<FICImageTableChunk>`.
 */
@interface FICImageTableEntry : NSObject

///---------------------------------------------
/// @name Accessing Image Table Entry Properties
///---------------------------------------------

/**
 The length, in bytes, of the entry data.
 
 @discussion Entries begin with the image data, followed by the metadata struct.
 */
@property (nonatomic, assign, readonly) size_t length;

/**
 The length, in bytes, of just the image data.
 */
@property (nonatomic, assign, readonly) size_t imageLength;

/**
 The bytes that represent the entry data.
 */
@property (nonatomic, assign, readonly) void *bytes;

/**
 The entity UUID, in byte form, associated with the entry.
 */
@property (nonatomic, assign) CFUUIDBytes entityUUIDBytes;

/**
 The source image UUID, in byte form, associated with the entry.
 */
@property (nonatomic, assign) CFUUIDBytes sourceImageUUIDBytes;

/**
 The image table chunk that contains this entry.
 */
@property (nonatomic, readonly) FICImageTableChunk *imageTableChunk;

/**
 A weak reference to the image cache that contains the image table chunk that contains this entry.
 */
@property (nonatomic, weak) FICImageCache *imageCache;

/**
 The index where this entry exists in the image table.
 */
@property (nonatomic, assign) NSInteger index;

///----------------------------------
/// @name Image Table Entry Lifecycle
///----------------------------------

/**
 Initializes a new image table entry from an image table chunk.
 
 @param imageTableChunk The image table chunk that contains the entry data.
 
 @param bytes The bytes from the chunk that contain the entry data.
 
 @param length The length, in bytes, of the entry data.
 
 @return A new image table entry.
 */
- (nullable instancetype)initWithImageTableChunk:(FICImageTableChunk *)imageTableChunk bytes:(void *)bytes length:(size_t)length;

/**
 Adds a block to be executed when this image table entry is deallocated.
 
 @param block A block that will be called when this image table entry is deallocated.
 
 @note Because of the highly-concurrent nature of Fast Image Cache, image tables must know when any of their entries are about to be deallocated to disassociate them with its internal data structures.
 */
- (void)executeBlockOnDealloc:(dispatch_block_t)block;

/**
 Forces the kernel to page in the memory-mapped, on-disk data backing this entry right away.
 */
- (void)preheat;

///--------------------------------------------
/// @name Flushing a Modified Image Table Entry
///--------------------------------------------

/**
 Writes a modified image table entry back to disk.
 */
- (void)flush;

///--------------------------------------------
/// @name Versioning Image Table Entry Metadata
///--------------------------------------------

/**
 Returns the current metadata version for image table entries.
 
 @return The integer version number of the current metadata version.
 
 @discussion Whenever the `<FICImageTableEntryMetadata>` struct is changed in any way, the metadata version must be changed.
 */
+ (NSInteger)metadataVersion;

@end

NS_ASSUME_NONNULL_END