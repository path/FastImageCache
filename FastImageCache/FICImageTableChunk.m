//
//  FICImageTableChunk.m
//  FastImageCache
//
//  Copyright (c) 2013 Path, Inc.
//  See LICENSE for full license agreement.
//

#import "FICImageTableChunk.h"

#import <sys/mman.h>

#pragma mark - Class Extension

@interface FICImageTableChunk () {
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
@synthesize length = _length;

#pragma mark - Object Lifecycle

- (instancetype)initWithFileDescriptor:(int)fileDescriptor index:(NSInteger)index length:(size_t)length {
    self = [super init];
    
    if (self != nil) {
        _index = index;
        _length = length;
        _fileOffset = _index * _length;
        _bytes = mmap(NULL, _length, (PROT_READ|PROT_WRITE), (MAP_FILE|MAP_SHARED), fileDescriptor, _fileOffset);

        if (_bytes == MAP_FAILED) {
            NSLog(@"Failed to map chunk. errno=%d", errno);
            _bytes = NULL;
            self = nil;
        }
    }
    
    return self;
}

- (void)dealloc {
    if (_bytes != NULL) {
        munmap(_bytes, _length);
    }
}

@end
