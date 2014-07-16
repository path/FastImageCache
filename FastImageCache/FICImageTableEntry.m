//
//  FICImageTableEntry.m
//  FastImageCache
//
//  Copyright (c) 2013 Path, Inc.
//  See LICENSE for full license agreement.
//

#import "FICImageTableEntry.h"
#import "FICImageTable.h"
#import "FICImageTableChunk.h"
#import "FICImageCache.h"

#import "FICImageCache+FICErrorLogging.h"

#import <sys/mman.h>

#pragma mark Class Extension

@interface FICImageTableEntry () {
    FICImageTableChunk *_imageTableChunk;
    void *_bytes;
    size_t _length;
    NSMutableArray *_deallocBlocks;
    NSInteger _index;
}

@end

#pragma mark

@implementation FICImageTableEntry

@synthesize bytes = _bytes;
@synthesize length = _length;
@synthesize imageTableChunk = _imageTableChunk;
@synthesize index = _index;
@synthesize imageCache;

#pragma mark - Property Accessors

- (size_t)imageLength {
    return _length - sizeof(FICImageTableEntryMetadata);
}

- (CFUUIDBytes)entityUUIDBytes {
    return [self _metadata]->_entityUUIDBytes;
}

- (void)setEntityUUIDBytes:(CFUUIDBytes)entityUUIDBytes {
    [self _metadata]->_entityUUIDBytes = entityUUIDBytes;
}

- (CFUUIDBytes)sourceImageUUIDBytes {
    return [self _metadata]->_sourceImageUUIDBytes;
}

- (void)setSourceImageUUIDBytes:(CFUUIDBytes)sourceImageUUIDBytes {
    [self _metadata]->_sourceImageUUIDBytes = sourceImageUUIDBytes;
}

#pragma mark - Object Lifecycle

- (id)initWithImageTableChunk:(FICImageTableChunk *)imageTableChunk bytes:(void *)bytes length:(size_t)length {
    self = [super init];
    
    if (self != nil) {
        // Safety check
        void *entryMax = bytes + length;
        void *chunkMax = [imageTableChunk bytes] + [imageTableChunk length];
        if (entryMax > chunkMax) {
            self = nil;
        } else {
            _imageTableChunk = imageTableChunk;
            _bytes = bytes;
            _length = length;
            _deallocBlocks = [[NSMutableArray alloc] init];
        }
    }
    
    return self;
}

- (void)executeBlockOnDealloc:(dispatch_block_t)block {
    [_deallocBlocks addObject:[block copy]];
}

- (void)dealloc {
    for (dispatch_block_t block in _deallocBlocks) {
        dispatch_async([FICImageCache dispatchQueue], block);
    }
}

#pragma mark - Other Accessors

+ (NSInteger)metadataVersion {
    return 8;
}

- (FICImageTableEntryMetadata *)_metadata {
    return (FICImageTableEntryMetadata *)(_bytes + [self imageLength]);
}

#pragma mark - Flushing a Modified Image Table Entry

- (void)flush {
    int pageSize = [FICImageTable pageSize];
    void *address = _bytes;
    size_t pageIndex = (size_t)address / pageSize;
    void *pageAlignedAddress = (void *)(pageIndex * pageSize);
    size_t bytesBeforeData = address - pageAlignedAddress;
    size_t bytesToFlush = (bytesBeforeData + _length);
    int result = msync(pageAlignedAddress, bytesToFlush, MS_SYNC);
    
    if (result) {
        NSString *message = [NSString stringWithFormat:@"*** FIC Error: %s msync(%p, %ld) returned %d errno=%d", __PRETTY_FUNCTION__, pageAlignedAddress, bytesToFlush, result, errno];
        [self.imageCache _logMessage:message];
    }
}

- (void)preheat {
    int pageSize = [FICImageTable pageSize];
    void *bytes = [self bytes];
    NSUInteger length = [self length];
    
    // Read a byte off of each VM page to force the kernel to page in the data
    for (NSUInteger i = 0; i < length; i += pageSize) {
        *((volatile uint8_t *)bytes + i);
    }
}

@end
