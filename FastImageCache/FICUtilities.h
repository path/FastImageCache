//
//  FICUtilities.h
//  FastImageCache
//
//  Copyright (c) 2013 Path, Inc.
//  See LICENSE for full license agreement.
//

#import "FICImports.h"

size_t FICByteAlign(size_t bytesPerRow, size_t alignment);
size_t FICByteAlignForCoreAnimation(size_t bytesPerRow);

NSUUID * FICUUIDWithUUIDBytes(CFUUIDBytes UUIDBytes);
CFUUIDBytes FICUUIDBytesWithUUID(NSUUID *UUID);
NSUUID * FICUUIDFromMD5HashOfString(NSString *string); // Useful for computing an entity's UUID from a URL, for example

