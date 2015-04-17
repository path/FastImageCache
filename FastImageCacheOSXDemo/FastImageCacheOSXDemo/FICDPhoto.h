//
//  FICDPhoto.h
//  FastImageCacheDemo
//
//  Copyright (c) 2013 Path, Inc.
//  See LICENSE for full license agreement.
//

#import "FICEntity.h"


@interface FICDPhoto : NSObject <FICEntity>
@property (nonatomic, copy) NSURL *sourceImageURL;
@property(retain) NSImage *image;

@end
