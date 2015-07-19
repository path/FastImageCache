//
//  FICImageCache+FICErrorLogging.h
//  FastImageCache
//
//  Copyright (c) 2013 Path, Inc.
//  See LICENSE for full license agreement.
//

#import "FICImageCache.h"

/**
 This category on `<FICImageCache>` simply exposes its private logging mechanism to other classes.
 */
@interface FICImageCache (FICErrorLogging)

///-----------------------------
/// @name Logging Error Messages
///-----------------------------

/**
 Passes an error message to the image cache.
 
 @param message A string representing the error message.
 
 @discussion Rather than logging directly to standard output, Fast Image Cache classes pass all error logging to the shared `<FICImageCache>` instance. `<FICImageCache>` then allows its delegate to handle the
 message.
 
 @see [FICImageCacheDelegate imageCache:errorDidOccurWithMessage:]
 */
- (void)_logMessage:(NSString *)message;

@end
