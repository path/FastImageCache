//
//  FICImageCache.m
//  FastImageCache
//
//  Copyright (c) 2013 Path, Inc.
//  See LICENSE for full license agreement.
//

#import "FICImageCache.h"
#import "FICEntity.h"
#import "FICImageTable.h"
#import "FICImageFormat.h"

#pragma mark Internal Definitions

static void _FICAddCompletionBlockForEntity(NSString *formatName, NSMutableDictionary *entityRequestsDictionary, id <FICEntity> entity, FICImageCacheCompletionBlock completionBlock);

static NSString *const FICImageCacheFormatKey = @"FICImageCacheFormatKey";
static NSString *const FICImageCacheCompletionBlocksKey = @"FICImageCacheCompletionBlocksKey";
static NSString *const FICImageCacheEntityKey = @"FICImageCacheEntityKey";

#pragma mark - Class Extension

@interface FICImageCache () {
    NSMutableDictionary *_formats;
    NSMutableDictionary *_imageTables;
    NSMutableDictionary *_requests;
    __weak id <FICImageCacheDelegate> _delegate;
    
    BOOL _delegateImplementsShouldProcessAllFormatsInFamilyForEntity;
    BOOL _delegateImplementsErrorDidOccurWithMessage;
    BOOL _delegateImplementsCancelImageLoadingForEntityWithFormatName;
}

@end

#pragma mark

@implementation FICImageCache

@synthesize delegate = _delegate;

#pragma mark - Property Accessors

- (void)setDelegate:(id<FICImageCacheDelegate>)delegate {
    if (delegate != _delegate) {
        _delegate = delegate;
        
        _delegateImplementsShouldProcessAllFormatsInFamilyForEntity = [_delegate respondsToSelector:@selector(imageCache:shouldProcessAllFormatsInFamily:forEntity:)];
        _delegateImplementsErrorDidOccurWithMessage = [_delegate respondsToSelector:@selector(imageCache:errorDidOccurWithMessage:)];
        _delegateImplementsCancelImageLoadingForEntityWithFormatName = [_delegate respondsToSelector:@selector(imageCache:cancelImageLoadingForEntity:withFormatName:)];
    }
}

static FICImageCache *__imageCache = nil;

#pragma mark - Object Lifecycle

+ (instancetype)sharedImageCache {
    if (__imageCache == nil) {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            __imageCache = [[[self class] alloc] init];
        });
    }
    
    return __imageCache;
}

+ (dispatch_queue_t)dispatchQueue {
    static dispatch_queue_t __imageCacheDispatchQueue = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        __imageCacheDispatchQueue = dispatch_queue_create("com.path.FastImageCacheQueue", NULL);
    });
    return __imageCacheDispatchQueue;
}

- (id)init {
    self = [super init];
    
    if (self != nil) {
        _formats = [[NSMutableDictionary alloc] init];
        _imageTables = [[NSMutableDictionary alloc] init];
        _requests = [[NSMutableDictionary alloc] init];
    }
    return self;
}

#pragma mark - Working with Formats

- (void)setFormats:(NSArray *)formats {
    if ([_formats count] > 0) {
        [self _logMessage:[NSString stringWithFormat:@"*** FIC Error: %s FICImageCache has already been configured with its image formats.", __PRETTY_FUNCTION__]];
    } else {
        NSMutableSet *imageTableFiles = [NSMutableSet set];
        FICImageFormatDevices currentDevice = [[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad ? FICImageFormatDevicePad : FICImageFormatDevicePhone;
        for (FICImageFormat *imageFormat in formats) {
            NSString *formatName = [imageFormat name];
            FICImageFormatDevices devices = [imageFormat devices];
            if (devices & currentDevice) {
                // Only initialize an image table for this format if it is needed on the current device.
                FICImageTable *imageTable = [[FICImageTable alloc] initWithFormat:imageFormat imageCache:self];
                [_imageTables setObject:imageTable forKey:formatName];
                [_formats setObject:imageFormat forKey:formatName];
                
                [imageTableFiles addObject:[[imageTable tableFilePath] lastPathComponent]];
                [imageTableFiles addObject:[[imageTable metadataFilePath] lastPathComponent]];
            }
        }
        
        // Remove any extraneous files in the image tables directory
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSString *directoryPath = [FICImageTable directoryPath];
        NSArray *fileNames = [fileManager contentsOfDirectoryAtPath:directoryPath error:nil];
        for (NSString *fileName in fileNames) {
            if ([imageTableFiles containsObject:fileName] == NO) {
                // This is an extraneous file, which is no longer needed.
                NSString* filePath = [directoryPath stringByAppendingPathComponent:fileName];
                [fileManager removeItemAtPath:filePath error:nil];
            }
        }
    }
}

- (FICImageFormat *)formatWithName:(NSString *)formatName {
    return [_formats objectForKey:formatName];
}

- (NSArray *)formatsWithFamily:(NSString *)family {
    NSMutableArray *formats = nil;
    for (FICImageFormat *format in [_formats allValues]) {
        if ([[format family] isEqualToString:family]) {
            if (formats == nil) {
                formats = [NSMutableArray array];
            }
            
            [formats addObject:format];
        }
    }
    
    return [formats copy];
}

#pragma mark - Retrieving Images

- (BOOL)retrieveImageForEntity:(id <FICEntity>)entity withFormatName:(NSString *)formatName completionBlock:(FICImageCacheCompletionBlock)completionBlock {
    return [self _retrieveImageForEntity:entity withFormatName:formatName loadSynchronously:YES completionBlock:completionBlock];
}

- (BOOL)asynchronouslyRetrieveImageForEntity:(id <FICEntity>)entity withFormatName:(NSString *)formatName completionBlock:(FICImageCacheCompletionBlock)completionBlock {
    return [self _retrieveImageForEntity:entity withFormatName:formatName loadSynchronously:NO completionBlock:completionBlock];
}

- (BOOL)_retrieveImageForEntity:(id <FICEntity>)entity withFormatName:(NSString *)formatName loadSynchronously:(BOOL)loadSynchronously completionBlock:(FICImageCacheCompletionBlock)completionBlock {
    BOOL imageExists = NO;
    
    FICImageTable *imageTable = [_imageTables objectForKey:formatName];
    NSString *entityUUID = [entity UUID];
    NSString *sourceImageUUID = [entity sourceImageUUID];
    
    if (loadSynchronously == NO && [imageTable entryExistsForEntityUUID:entityUUID sourceImageUUID:sourceImageUUID]) {
        imageExists = YES;
        
        dispatch_async([FICImageCache dispatchQueue], ^{
            UIImage *image = [imageTable newImageForEntityUUID:entityUUID sourceImageUUID:sourceImageUUID preheatData:YES];
            
            if (completionBlock != nil) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completionBlock(entity, formatName, image);
                });
            }
        });
    } else {
        UIImage *image = [imageTable newImageForEntityUUID:entityUUID sourceImageUUID:sourceImageUUID preheatData:NO];
        imageExists = image != nil;
        
        dispatch_block_t completionBlockCallingBlock = ^{
            if (completionBlock != nil) {
                if (loadSynchronously) {
                    completionBlock(entity, formatName, image);
                } else {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        completionBlock(entity, formatName, image);
                    });
                }
            }
        };
        
        if (image == nil && _delegate != nil) {
            // No image for this UUID exists in the image table. We'll need to ask the delegate to retrieve the source asset.
            NSURL *sourceImageURL = [entity sourceImageURLWithFormatName:formatName];
            
            if (sourceImageURL != nil) {
                // We check to see if this image is already being fetched.
                NSMutableDictionary *requestDictionary = [_requests objectForKey:sourceImageURL];
                if (requestDictionary == nil) {
                    // If we're here, then we aren't currently fetching this image.
                    NSMutableDictionary *requestDictionary = [NSMutableDictionary dictionary];
                    [_requests setObject:requestDictionary forKey:sourceImageURL];
                    
                    _FICAddCompletionBlockForEntity(formatName, requestDictionary, entity, completionBlock);
                    [_delegate imageCache:self wantsSourceImageForEntity:entity withFormatName:formatName completionBlock:^(UIImage *sourceImage) {
                        [self _imageDidLoad:sourceImage forURL:sourceImageURL];
                    }];
                } else {
                    // We have an existing request dictionary, which means this URL is currently being fetched.
                    _FICAddCompletionBlockForEntity(formatName, requestDictionary, entity, completionBlock);
                }
            } else {
                NSString *message = [NSString stringWithFormat:@"*** FIC Error: %s entity %@ returned a nil source image URL for image format %@.", __PRETTY_FUNCTION__, entity, formatName];
                [self _logMessage:message];
                
                completionBlockCallingBlock();
            }
        } else {
            completionBlockCallingBlock();
        }
    }
    
    return imageExists;
}

- (void)_imageDidLoad:(UIImage *)image forURL:(NSURL *)URL {
    NSDictionary *requestDictionary = [_requests objectForKey:URL];
    if (requestDictionary != nil) {
        for (NSMutableDictionary *entityDictionary in [requestDictionary allValues]) {
            id <FICEntity> entity = [entityDictionary objectForKey:FICImageCacheEntityKey];
            NSString *formatName = [entityDictionary objectForKey:FICImageCacheFormatKey];
            NSDictionary *completionBlocksDictionary = [entityDictionary objectForKey:FICImageCacheCompletionBlocksKey];
            if (image != nil){
                [self _processImage:image forEntity:entity withFormatName:formatName completionBlocksDictionary:completionBlocksDictionary];
            } else {
                NSArray *completionBlocks = [completionBlocksDictionary objectForKey:formatName];
                if (completionBlocks != nil) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        for (FICImageCacheCompletionBlock completionBlock in completionBlocks) {
                            completionBlock(entity, formatName, nil);
                        }
                    });
                }
            }
        }
    }
    
    [_requests removeObjectForKey:URL];
}

static void _FICAddCompletionBlockForEntity(NSString *formatName, NSMutableDictionary *entityRequestsDictionary, id <FICEntity> entity, FICImageCacheCompletionBlock completionBlock) {
    NSString *entityUUID = [entity UUID];
    NSMutableDictionary *requestDictionary = [entityRequestsDictionary objectForKey:entityUUID];
    NSMutableDictionary *completionBlocks = nil;
    
    if (requestDictionary == nil) {
        // This is the first time we're dealing with this particular entity for this URL request.
        requestDictionary = [NSMutableDictionary dictionaryWithObjectsAndKeys:entity, FICImageCacheEntityKey, nil];
        [entityRequestsDictionary setObject:requestDictionary forKey:entityUUID];
        [requestDictionary setObject:formatName forKey:FICImageCacheFormatKey];
        
        // Dictionary where keys are imageFormats, and each value is an array of the completion blocks for the requests for this
        // URL at the specified format.
        completionBlocks = [NSMutableDictionary dictionary];
        [requestDictionary setObject:completionBlocks forKey:FICImageCacheCompletionBlocksKey];
    } else {
        // We already have a request dictionary for this entity, so we just need to append a completion block.
        completionBlocks = [requestDictionary objectForKey:FICImageCacheCompletionBlocksKey];
    }
    
    if (completionBlock != nil) {
        NSMutableArray *blocksArray = [completionBlocks objectForKey:formatName];
        if (blocksArray == nil) {
            blocksArray = [NSMutableArray array];
            [completionBlocks setObject:blocksArray forKey:formatName];
        }
        
        FICImageCacheCompletionBlock completionBlockCopy = [completionBlock copy];
        [blocksArray addObject:completionBlockCopy];
    }
}

#pragma mark - Storing Images

- (void)setImage:(UIImage *)image forEntity:(id <FICEntity>)entity withFormatName:(NSString *)formatName completionBlock:(FICImageCacheCompletionBlock)completionBlock {
    if (image != nil && entity != nil) {
        NSDictionary *completionBlocksDictionary = nil;
        
        if (completionBlock != nil) {
            completionBlocksDictionary = [NSDictionary dictionaryWithObject:[NSArray arrayWithObject:[completionBlock copy]] forKey:formatName];
        }
        
        NSString *entityUUID = [entity UUID];
        FICImageTable *imageTable = [_imageTables objectForKey:formatName];
        [imageTable deleteEntryForEntityUUID:entityUUID];
        
        [self _processImage:image forEntity:entity withFormatName:formatName completionBlocksDictionary:completionBlocksDictionary];
    }
}

- (void)_processImage:(UIImage *)image forEntity:(id <FICEntity>)entity withFormatName:(NSString *)formatName completionBlocksDictionary:(NSDictionary *)completionBlocksDictionary {
    FICImageFormat *imageFormat = [_formats objectForKey:formatName];
    NSString *formatFamily = [imageFormat family];
    NSString *entityUUID = [entity UUID];
    NSString *sourceImageUUID = [entity sourceImageUUID];
    
    if (formatFamily != nil) {
        BOOL shouldProcessAllFormatsInFamily = YES;
        if (_delegateImplementsShouldProcessAllFormatsInFamilyForEntity) {
            shouldProcessAllFormatsInFamily = [_delegate imageCache:self shouldProcessAllFormatsInFamily:formatFamily forEntity:entity];
        }
        // All of the formats in a given family use the same source asset, so once we have that source asset, we can generate all of the family's formats.
        for (FICImageTable *table in [_imageTables allValues]) {
            FICImageFormat *imageFormat = [table imageFormat];
            NSString *tableFormatFamily = [imageFormat family];
            if ([formatFamily isEqualToString:tableFormatFamily]) {
                NSArray *completionBlocks = [completionBlocksDictionary objectForKey:[imageFormat name]];
                
                BOOL imageExistsForEntity = [table entryExistsForEntityUUID:entityUUID sourceImageUUID:sourceImageUUID];
                BOOL shouldProcessFamilyFormat = shouldProcessAllFormatsInFamily && imageExistsForEntity == NO;
                if (shouldProcessFamilyFormat || [completionBlocks count] > 0) {
                    [self _processImage:image forEntity:entity imageTable:table completionBlocks:completionBlocks];
                }
            }
        }
    } else {
        FICImageTable *imageTable = [_imageTables objectForKey:formatName];
        NSArray *completionBlocks = [completionBlocksDictionary objectForKey:formatName];
        [self _processImage:image forEntity:entity imageTable:imageTable completionBlocks:completionBlocks];
    }
}

- (void)_processImage:(UIImage *)image forEntity:(id <FICEntity>)entity imageTable:(FICImageTable *)imageTable completionBlocks:(NSArray *)completionBlocks {
    if (imageTable != nil) {
        if ([entity UUID] == nil) {
            [self _logMessage:[NSString stringWithFormat:@"*** FIC Error: %s entity %@ is missing its UUID.", __PRETTY_FUNCTION__, entity]];
            return;
        }
        
        if ([entity sourceImageUUID] == nil) {
            [self _logMessage:[NSString stringWithFormat:@"*** FIC Error: %s entity %@ is missing its source image UUID.", __PRETTY_FUNCTION__, entity]];
            return;
        }
        
        NSString *entityUUID = [entity UUID];
        NSString *sourceImageUUID = [entity sourceImageUUID];
        FICImageFormat *imageFormat = [imageTable imageFormat];
        NSString *imageFormatName = [imageFormat name];
        FICEntityImageDrawingBlock imageDrawingBlock = [entity drawingBlockForImage:image withFormatName:imageFormatName];
        
        dispatch_async([FICImageCache dispatchQueue], ^{
            [imageTable setEntryForEntityUUID:entityUUID sourceImageUUID:sourceImageUUID imageDrawingBlock:imageDrawingBlock];

            UIImage *resultImage = [imageTable newImageForEntityUUID:entityUUID sourceImageUUID:sourceImageUUID preheatData:NO];
            
            if (completionBlocks != nil) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    NSString *formatName = [[imageTable imageFormat] name];
                    for (FICImageCacheCompletionBlock completionBlock in completionBlocks) {
                        completionBlock(entity, formatName, resultImage);
                    }
                });
            }
        });
    }
}

#pragma mark - Checking for Image Existence

- (BOOL)imageExistsForEntity:(id <FICEntity>)entity withFormatName:(NSString *)formatName {
    FICImageTable *imageTable = [_imageTables objectForKey:formatName];
    NSString *entityUUID = [entity UUID];
    NSString *sourceImageUUID = [entity sourceImageUUID];
    
    BOOL imageExists = [imageTable entryExistsForEntityUUID:entityUUID sourceImageUUID:sourceImageUUID];

    return imageExists;
}

#pragma mark - Invalidating Image Data

- (void)deleteImageForEntity:(id <FICEntity>)entity withFormatName:(NSString *)formatName {
    FICImageTable *imageTable = [_imageTables objectForKey:formatName];
    NSString *entityUUID = [entity UUID];    
    [imageTable deleteEntryForEntityUUID:entityUUID];
}

- (void)cancelImageRetrievalForEntity:(id <FICEntity>)entity withFormatName:(NSString *)formatName {
    NSURL *sourceImageURL = [entity sourceImageURLWithFormatName:formatName];
    NSMutableDictionary *requestDictionary = [_requests objectForKey:sourceImageURL];
    if (requestDictionary) {
        NSString *entityUUID = [entity UUID];
        NSMutableDictionary *entityRequestsDictionary = [requestDictionary objectForKey:entityUUID];
        if (entityRequestsDictionary) {
            NSMutableDictionary *completionBlocksDictionary = [entityRequestsDictionary objectForKey:FICImageCacheCompletionBlocksKey];
            [completionBlocksDictionary removeObjectForKey:formatName];
            
            if ([completionBlocksDictionary count] == 0) {
                [requestDictionary removeObjectForKey:entityUUID];
            }
            
            if ([requestDictionary count] == 0) {
                [_requests removeObjectForKey:sourceImageURL];
                
                if (_delegateImplementsCancelImageLoadingForEntityWithFormatName) {
                    [_delegate imageCache:self cancelImageLoadingForEntity:entity withFormatName:formatName];
                }
            }
        }
    }
}

- (void)reset {
    for (FICImageTable *imageTable in [_imageTables allValues]) {
        [imageTable reset];
    }
}

#pragma mark - Logging Errors

- (void)_logMessage:(NSString *)message {
    if (_delegateImplementsErrorDidOccurWithMessage) {
        [_delegate imageCache:self errorDidOccurWithMessage:message];
    }
}

@end
