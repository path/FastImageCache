//
//  FICUtilities.m
//  FastImageCache
//
//  Copyright (c) 2013 Path, Inc.
//  See LICENSE for full license agreement.
//

#import "FICUtilities.h"

#import <CommonCrypto/CommonDigest.h>

#pragma mark Internal Definitions

// Core Animation will make a copy of any image that a client application provides whose backing store isn't properly byte-aligned.
// This copy operation can be prohibitively expensive, so we want to avoid this by properly aligning any UIImages we're working with.
// To produce a UIImage that is properly aligned, we need to ensure that the backing store's bytes per row is a multiple of 64.

#pragma mark - Byte Alignment

inline size_t FICByteAlign(size_t width, size_t alignment) {
    return ((width + (alignment - 1)) / alignment) * alignment;
}

inline size_t FICByteAlignForCoreAnimation(size_t bytesPerRow) {
    return FICByteAlign(bytesPerRow, 64);
}

#pragma mark - Strings and UUIDs

NSUUID * FICUUIDWithUUIDBytes(CFUUIDBytes UUIDBytes) {
    NSUUID *UUID = [[NSUUID alloc] initWithUUIDBytes:(const unsigned char *)&UUIDBytes];
    return UUID;
}

CFUUIDBytes FICUUIDBytesWithUUID(NSUUID *UUID) {
    CFUUIDBytes UUIDBytes;
    
    if (UUID != nil) {
        [UUID getUUIDBytes:(unsigned char *)&UUIDBytes];
    }
    
    return UUIDBytes;
}

NSUUID * FICUUIDFromMD5HashOfString(NSString *string) {
    const char *UTF8String = [string UTF8String];
    CFUUIDBytes UUIDBytes;
    
    CC_MD5(UTF8String, strlen(UTF8String), (unsigned char*)&UUIDBytes);
    
    NSUUID *UUID = FICUUIDWithUUIDBytes(UUIDBytes);

    return UUID;
}
