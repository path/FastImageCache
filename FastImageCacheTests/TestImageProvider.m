//
//  TestImageProvider.m
//  FastImageCache
//
//  Copyright (c) 2013 Path, Inc.
//  See LICENSE for full license agreement.
//

#import "TestImageProvider.h"
#import "FICEntity.h"

@implementation TestImageProvider

- (void)imageCache:(FICImageCache *)imageCache wantsSourceImageForEntity:(id<FICEntity>)entity withFormatName:(NSString *)formatName completionBlock:(FICImageRequestCompletionBlock)completionBlock {
    // Images typically come from the Internet rather than from the app bundle directly, so this would be the place to fire off a network request to download the image.
    // For the purposes of this demo app, we'll just access images stored locally on disk.
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        UIImage *sourceImage = [[UIImage alloc] init];
        dispatch_async(dispatch_get_main_queue(), ^{
            completionBlock(sourceImage);
        });
    });
}

@end
