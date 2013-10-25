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
static NSString *const FICImageFormatStyleKey = @"style";
static NSString *const FICImageFormatMaximumCountKey = @"maximumCount";
static NSString *const FICImageFormatDevicesKey = @"devices";

#pragma mark - Class Extension

@interface FICImageFormat () {
    NSString *_name;
    NSString *_family;
    CGSize _imageSize;
    CGSize _pixelSize;
    FICImageFormatStyle _style;
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
@synthesize style = _style;
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

- (CGBitmapInfo)bitmapInfo {
    CGBitmapInfo info;
    switch (_style) {
        case FICImageFormatStyle32BitBGRA:
            info = kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Host;
            break;
        case FICImageFormatStyle32BitBGR:
            info = kCGImageAlphaNoneSkipFirst | kCGBitmapByteOrder32Host;
            break;
        case FICImageFormatStyle16BitBGR:
            info = kCGImageAlphaNoneSkipFirst | kCGBitmapByteOrder16Host;
            break;
        case FICImageFormatStyle8BitGrayscale:
            info = (CGBitmapInfo)kCGImageAlphaNone;
            break;
    }
    return info;
}

- (NSInteger)bytesPerPixel {
    NSInteger bytesPerPixel;
    switch (_style) {
        case FICImageFormatStyle32BitBGRA:
        case FICImageFormatStyle32BitBGR:
            bytesPerPixel = 4;
            break;
        case FICImageFormatStyle16BitBGR:
            bytesPerPixel = 2;
            break;
        case FICImageFormatStyle8BitGrayscale:
            bytesPerPixel = 1;
            break;
    }
    return bytesPerPixel;
}

- (NSInteger)bitsPerComponent {
    NSInteger bitsPerComponent;
    switch (_style) {
        case FICImageFormatStyle32BitBGRA:
        case FICImageFormatStyle32BitBGR:
        case FICImageFormatStyle8BitGrayscale:
            bitsPerComponent = 8;
            break;
        case FICImageFormatStyle16BitBGR:
            bitsPerComponent = 5;
            break;
    }
    return bitsPerComponent;
}

- (BOOL)isGrayscale {
    BOOL isGrayscale;
    switch (_style) {
        case FICImageFormatStyle32BitBGRA:
        case FICImageFormatStyle32BitBGR:
        case FICImageFormatStyle16BitBGR:
            isGrayscale = NO;
            break;
        case FICImageFormatStyle8BitGrayscale:
            isGrayscale = YES;
            break;
    }
    return isGrayscale;
}

#pragma mark - Object Lifecycle

+ (instancetype)formatWithName:(NSString *)name family:(NSString *)family imageSize:(CGSize)imageSize style:(FICImageFormatStyle)style maximumCount:(NSInteger)maximumCount devices:(FICImageFormatDevices)devices {
    FICImageFormat *imageFormat = [[FICImageFormat alloc] init];
    
    [imageFormat setName:name];
    [imageFormat setFamily:family];
    [imageFormat setImageSize:imageSize];
    [imageFormat setStyle:style];
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
    [dictionaryRepresentation setValue:[NSNumber numberWithInt:_style] forKey:FICImageFormatStyleKey];
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
    [imageFormatCopy setStyle:[self style]];
    [imageFormatCopy setMaximumCount:[self maximumCount]];
    [imageFormatCopy setDevices:[self devices]];
    
    return imageFormatCopy;
}

@end
