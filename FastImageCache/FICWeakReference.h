//
//  FICWeakReference.h
//  FastImageCache
//
//  Copyright (c) 2014 Path, Inc.
//  See LICENSE for full license agreement.
//

#import "FICImports.h"

@interface FICWeakReference : NSObject

- (instancetype)initWithObject:(id)object;

@property(nonatomic, weak) id object;

@end
