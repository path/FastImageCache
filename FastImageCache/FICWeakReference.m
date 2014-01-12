//
//  FICWeakReference.m
//  FastImageCache
//
//  Copyright (c) 2014 Path, Inc.
//  See LICENSE for full license agreement.
//

#import "FICWeakReference.h"

@implementation FICWeakReference

- (instancetype)initWithObject:(id)object {
    if (self = [super init]) {
        _object = object;
    }
    return self;
}

@end
