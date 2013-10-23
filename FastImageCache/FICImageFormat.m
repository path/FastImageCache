//
//  FICImageFormat.m
//  FastImageCache
//
//  Copyright (c) 2013 Path, Inc.
//  See LICENSE for full license agreement.
//

#import "FICImageFormat.h"
#import "FICImageTable.h"
#import "FICImageTableEntry.h"

#pragma mark Internal Definitions

static NSString *const FICImageFormatNameKey = @"name";
static NSString *const FICImageFormatFamilyKey = @"family";
static NSString *const FICImageFormatWidthKey = @"width";
static NSString *const FICImageFormatHeightKey = @"height";
static NSString *const FICImageFormatIsOpaqueKey = @"isOpaque";
static NSString *const FICImageFormatMaximumCountKey = @"maximumCount";
static NSString *const FICImageFormatDevicesKey = @"devices";

#pragma mark - Class Extension

@interface FICImageFormat () {
    NSString *_name;
    NSString *_family;
    CGSize _imageSize;
    CGSize _pixelSize;
    BOOL _isOpaque;
    NSInteger _maximumCount;
    FICImageFormatDevices _devices;
}

@end

#pragma mark

@implementation FICImageFormat

@synthesize name = _name;
@synthesize family = _family;
@synthesize imageSize = _imageSize;
@synthesize pixelSize = _pixelSize;
@synthesize opaque = _isOpaque;
@synthesize maximumCount = _maximumCount;
@synthesize devices = _devices;

#pragma mark - Property Accessors

- (void)setImageSize:(CGSize)imageSize {
    BOOL currentSizeEqualToNewSize = CGSizeEqualToSize(imageSize, _imageSize);
    if (currentSizeEqualToNewSize == NO) {
        _imageSize = imageSize;
        
        CGFloat screenScale = [[UIScreen mainScreen] scale];
        _pixelSize = CGSizeMake(screenScale * _imageSize.width, screenScale * _imageSize.height);
    }
}

#pragma mark - Object Lifecycle

+ (instancetype)formatWithName:(NSString *)name family:(NSString *)family imageSize:(CGSize)imageSize isOpaque:(BOOL)isOpaque maximumCount:(NSInteger)maximumCount devices:(FICImageFormatDevices)devices {
    FICImageFormat *imageFormat = [[FICImageFormat alloc] init];
    
    [imageFormat setName:name];
    [imageFormat setFamily:family];
    [imageFormat setImageSize:imageSize];
    [imageFormat setOpaque:isOpaque];
    [imageFormat setMaximumCount:maximumCount];
    [imageFormat setDevices:devices];
    
    return imageFormat;
}

#pragma mark - Working with Dictionary Representations

- (NSDictionary *)dictionaryRepresentation {
    NSMutableDictionary *dictionaryRepresentation = [NSMutableDictionary dictionary];
    
    [dictionaryRepresentation setValue:_name forKey:FICImageFormatNameKey];
    [dictionaryRepresentation setValue:_family forKey:FICImageFormatFamilyKey];
    [dictionaryRepresentation setValue:[NSNumber numberWithUnsignedInteger:_imageSize.width] forKey:FICImageFormatWidthKey];
    [dictionaryRepresentation setValue:[NSNumber numberWithUnsignedInteger:_imageSize.height] forKey:FICImageFormatHeightKey];
    [dictionaryRepresentation setValue:[NSNumber numberWithBool:_isOpaque] forKey:FICImageFormatIsOpaqueKey];
    [dictionaryRepresentation setValue:[NSNumber numberWithUnsignedInteger:_maximumCount] forKey:FICImageFormatMaximumCountKey];
    [dictionaryRepresentation setValue:[NSNumber numberWithInt:_devices] forKey:FICImageFormatDevicesKey];
    [dictionaryRepresentation setValue:[NSNumber numberWithFloat:[[UIScreen mainScreen] scale]] forKey:FICImageTableScreenScaleKey];
    [dictionaryRepresentation setValue:[NSNumber numberWithUnsignedInteger:[FICImageTableEntry metadataVersion]] forKey:FICImageTableEntryDataVersionKey];
    
    return dictionaryRepresentation;
}

#pragma mark - Protocol Implementations

#pragma mark - NSObject (NSCopying)

- (id)copyWithZone:(NSZone *)zone {
    FICImageFormat *imageFormatCopy = [[FICImageFormat alloc] init];
    
    [imageFormatCopy setName:[self name]];
    [imageFormatCopy setFamily:[self family]];
    [imageFormatCopy setImageSize:[self imageSize]];
    [imageFormatCopy setOpaque:[self isOpaque]];
    [imageFormatCopy setMaximumCount:[self maximumCount]];
    [imageFormatCopy setDevices:[self devices]];
    
    return imageFormatCopy;
}

@end
