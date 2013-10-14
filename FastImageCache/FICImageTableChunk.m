//
//  FICImageTableChunk.m
//  FastImageCache
//
//  Copyright (c) 2013 Path, Inc.
//  See LICENSE for full license agreement.
//

#import "FICImageTableChunk.h"
#import "FICImageTable.h"

#import <sys/mman.h>

#pragma mark FICImageTable (FICImageTableChunkAdditions)

@interface FICImageTable (FICImageTableChunkAdditions)

- (void)_chunkWillBeDeallocated:(FICImageTableChunk *)chunk;

@end

#pragma mark - Class Extension

@interface FICImageTableChunk () {
    FICImageTable *_owningImageTable;
    NSInteger _index;
    void *_bytes;
    size_t _length;
    off_t _fileOffset;
}

@end

#pragma mark

@implementation FICImageTableChunk

@synthesize bytes = _bytes;
@synthesize fileOffset = _fileOffset;

#pragma mark - Object Lifecycle

- (id)initWithImageTable:(FICImageTable *)imageTable fileDescriptor:(int)fileDescriptor index:(NSInteger)index length:(size_t)length {
    self = [super init];
    
    if (self != nil) {
        _owningImageTable = [imageTable retain];
        _index = index;
        _length = length;
        _fileOffset = _index * _length;
        _bytes = mmap(NULL, _length, (PROT_READ|PROT_WRITE), (MAP_FILE|MAP_SHARED), fileDescriptor, _fileOffset);

        if (_bytes == MAP_FAILED) {
            _bytes = NULL;
        }
    }
    
    return self;
}

- (void)dealloc {
    [_owningImageTable release];
    
    if (_bytes != NULL) {
        munmap(_bytes, _length);
    }
    
    [super dealloc];
}

- (oneway void)release {
    // While it is good practice to never access retainCount, in this case, it is necessary. This is the only way
    // to know that self will soon be deallocated prior to the start of execution of the dealloc method.
    if ([self retainCount] == 1) {
        [_owningImageTable _chunkWillBeDeallocated:self]; 
    }
    
    [super release];
}

@end
