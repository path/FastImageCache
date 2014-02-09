//
//  FICImageTableEntry.h
//  FastImageCache
//
//  Copyright (c) 2013 Path, Inc.
//  See LICENSE for full license agreement.
//

#import "FICImports.h"

@class FICImageTableChunk;

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

@property (nonatomic, readonly) FICImageTableChunk *imageTableChunk;

@property (nonatomic, assign) NSInteger index;

- (void)preheat;

///----------------------------------------
/// @name Initializing an Image Table Entry
///----------------------------------------

/**
 Initializes a new image table entry from an image table chunk.
 
 @param imageTableChunk The image table chunk that contains the entry data.
 
 @param bytes The bytes from the chunk that contain the entry data.
 
 @param length The length, in bytes, of the entry data.
 
 @return A new image table entry.
 */
- (instancetype)initWithImageTableChunk:(FICImageTableChunk *)imageTableChunk bytes:(void *)bytes length:(size_t)length;

- (void)executeBlockOnDealloc:(dispatch_block_t)block;

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
