//
//  FICImageTableChunk.h
//  FastImageCache
//
//  Copyright (c) 2013 Path, Inc.
//  See LICENSE for full license agreement.
//

#import "FICImports.h"

NS_ASSUME_NONNULL_BEGIN

@class FICImageTable;

/**
 `FICImageTableChunk` represents a contiguous portion of image table file data.
 */
@interface FICImageTableChunk : NSObject

///-----------------------------------
/// @name Image Table Chunk Properties
///-----------------------------------

/**
 The bytes of file data contained in the chunk.
 
 @discussion `FICImageTableChunk` maps file data directly to `bytes`, so no memory copy occurs.
 */
@property (nonatomic, assign, readonly) void *bytes;

/**
 The index of the chunk in the image table file.
 */
@property (nonatomic, assign, readonly) NSInteger index;

/**
 The offset in the image table file where the chunk begins.
 */
@property (nonatomic, assign, readonly) off_t fileOffset;

/**
 The length, in bytes, of the chunk.
 */
@property (nonatomic, assign, readonly) size_t length;


///----------------------------------------
/// @name Initializing an Image Table Chunk
///----------------------------------------

/**
 Initializes a new image table chunk.

 @param fileDescriptor The image table's file descriptor to map from.
 
 @param index The index of the chunk.
 
 @param length The length, in bytes, of the chunk.
 
 @return A new image table chunk.
 */
- (nullable instancetype)initWithFileDescriptor:(int)fileDescriptor index:(NSInteger)index length:(size_t)length;

@end

NS_ASSUME_NONNULL_END