//
//  FICImageTable.m
//  FastImageCache
//
//  Copyright (c) 2013 Path, Inc.
//  See LICENSE for full license agreement.
//

#import "FICImageTable.h"
#import "FICImageFormat.h"
#import "FICImageCache.h"
#import "FICImageTableChunk.h"
#import "FICImageTableEntry.h"
#import "FICUtilities.h"

#import "FICImageCache+FICErrorLogging.h"

#pragma mark External Definitions

NSString *const FICImageTableEntryDataVersionKey = @"FICImageTableEntryDataVersionKey";
NSString *const FICImageTableScreenScaleKey = @"FICImageTableScreenScaleKey";

#pragma mark - Internal Definitions

static NSString *const FICImageTableMetadataFileExtension = @"metadata";
static NSString *const FICImageTableFileExtension = @"imageTable";

static NSString *const FICImageTableIndexMapKey = @"indexMap";
static NSString *const FICImageTableContextMapKey = @"contextMap";
static NSString *const FICImageTableMRUArrayKey = @"mruArray";
static NSString *const FICImageTableFormatKey = @"format";

#pragma mark - Class Extension

@interface FICImageTable () {
    FICImageFormat *_imageFormat;
    CGFloat _screenScale;
    NSInteger _imageRowLength;
    
    NSString *_filePath;
    int _fileDescriptor;
    off_t _fileLength;
    
    NSUInteger _entryCount;
    NSInteger _entryLength;
    NSUInteger _entriesPerChunk;
    NSInteger _imageLength;
    
    size_t _chunkLength;
    NSInteger _chunkCount;
    
    NSMapTable *_chunkMapTable;
    NSMutableArray *_recentChunks;
    NSRecursiveLock *_lock;
    
    // Image table metadata
    NSMutableDictionary *_indexMap;         // Key: entity UUID, value: integer index into the table file
    NSMutableDictionary *_sourceImageMap;   // Key: entity UUID, value: source image UUID
    NSMutableIndexSet *_occupiedIndexes;
    NSMutableOrderedSet *_MRUEntries;
    NSDictionary *_imageFormatDictionary;
}

@end

#pragma mark

@implementation FICImageTable

@synthesize imageFormat =_imageFormat;

#pragma mark - Property Accessors (Public)

- (NSString *)tableFilePath {
    NSString *tableFilePath = [[_imageFormat name] stringByAppendingPathExtension:FICImageTableFileExtension];
    tableFilePath = [[FICImageTable directoryPath] stringByAppendingPathComponent:tableFilePath];
    
    return tableFilePath;
}

- (NSString *)metadataFilePath {
    NSString *metadataFilePath = [[_imageFormat name] stringByAppendingPathExtension:FICImageTableMetadataFileExtension];
    metadataFilePath = [[FICImageTable directoryPath] stringByAppendingPathComponent:metadataFilePath];
    
    return metadataFilePath;
}

#pragma mark - Class-Level Definitions

+ (int)pageSize {
    static int __pageSize = 0;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        __pageSize = getpagesize();
    });

    return __pageSize;
}

+ (NSString *)directoryPath {
    static NSString *__directoryPath = nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
        __directoryPath = [[paths objectAtIndex:0] stringByAppendingPathComponent:@"ImageTables"];
        
        NSFileManager *fileManager = [[NSFileManager alloc] init];
        BOOL directoryExists = [fileManager fileExistsAtPath:__directoryPath];
        if (directoryExists == NO) {
            [fileManager createDirectoryAtPath:__directoryPath withIntermediateDirectories:YES attributes:nil error:nil];
        }
    });
    
    return __directoryPath;
}

#pragma mark - Object Lifecycle

- (instancetype)initWithFormat:(FICImageFormat *)imageFormat {
    self = [super init];
    
    if (self != nil) {
        if (imageFormat == nil) {
            [NSException raise:NSInvalidArgumentException format:@"*** FIC Exception: %s must pass in an image format.", __PRETTY_FUNCTION__];
        }
        
        _lock = [[NSRecursiveLock alloc] init];
        _imageFormat = [imageFormat copy];
        _imageFormatDictionary = [imageFormat dictionaryRepresentation];
        
        _screenScale = [[UIScreen mainScreen] scale];
        
        CGSize pixelSize = [_imageFormat pixelSize];
        NSInteger bytesPerPixel = [_imageFormat bytesPerPixel];
        _imageRowLength = (NSInteger)FICByteAlignForCoreAnimation(pixelSize.width * bytesPerPixel);
        _imageLength = _imageRowLength * (NSInteger)pixelSize.height;
        
        _chunkMapTable = [NSMapTable mapTableWithKeyOptions:NSMapTableStrongMemory valueOptions:NSMapTableWeakMemory];
        
        _indexMap = [[NSMutableDictionary alloc] init];
        _occupiedIndexes = [[NSMutableIndexSet alloc] init];
        
        _MRUEntries = [[NSMutableOrderedSet alloc] init];
        _sourceImageMap = [[NSMutableDictionary alloc] init];
        
        _recentChunks = [[NSMutableArray alloc] init];
        
        _filePath = [[self tableFilePath] copy];
        
        [self _loadMetadata];
        
        _fileDescriptor = open([_filePath fileSystemRepresentation], O_RDWR | O_CREAT, 0666);
        
        if (_fileDescriptor >= 0) {
            // The size of each entry in the table needs to be page-aligned. This will cause each entry to have a page-aligned base
            // address, which will help us avoid Core Animation having to copy our images when we eventually set them on layers.
            _entryLength = (NSInteger)FICByteAlign(_imageLength + sizeof(FICImageTableEntryMetadata), [FICImageTable pageSize]);
            
            // Each chunk will map in n entries. Try to keep the chunkLength around 2MB.
            NSInteger goalChunkLength = 2 * (1024 * 1024);
            NSInteger goalEntriesPerChunk = goalChunkLength / _entryLength;
            _entriesPerChunk = MAX(4, goalEntriesPerChunk);
            _chunkLength = (size_t)(_entryLength * _entriesPerChunk);
            
            _fileLength = lseek(_fileDescriptor, 0, SEEK_END);
            _entryCount = (NSInteger)(_fileLength / _entryLength);
            _chunkCount = (_entryCount + _entriesPerChunk - 1) / _entriesPerChunk;
            
            if ([_indexMap count] > _entryCount) {
                // It's possible that someone deleted the image table file but left behind the metadata file. If this happens, the metadata
                // will obviously become out of sync with the image table file, so we need to reset the image table.
                [self reset];
            }
        } else {
            // If something goes wrong and we can't open the image table file, then we have no choice but to release and nil self.
            NSString *message = [NSString stringWithFormat:@"*** FIC Error: %s could not open the image table file at path %@. The image table was not created.", __PRETTY_FUNCTION__, _filePath];
            [[FICImageCache sharedImageCache] _logMessage:message];

            self = nil;
        }    
    }
    
    return self;
}

- (instancetype)init {
    return [self initWithFormat:nil];
}

- (void)dealloc {
    if (_fileDescriptor >= 0) {
        close(_fileDescriptor);
    }
}

#pragma mark - Working with Chunks

- (FICImageTableChunk *)_cachedChunkAtIndex:(NSInteger)index {
    FICImageTableChunk *cachedChunk = [_chunkMapTable objectForKey:@(index)];
    
    return cachedChunk;
}

- (void)_setChunk:(FICImageTableChunk *)chunk index:(NSInteger)index {
    if (chunk != nil) {
        [_chunkMapTable setObject:chunk forKey:@(index)];
    } else {
        [_chunkMapTable removeObjectForKey:@(index)];
    }
}

- (FICImageTableChunk *)_chunkAtIndex:(NSInteger)index {
    FICImageTableChunk *chunk = nil;
    
    if (index < _chunkCount) {
        chunk = [self _cachedChunkAtIndex:index];
        
        if (chunk == nil) {
            size_t chunkLength = _chunkLength;
            off_t chunkOffset = index * (off_t)_chunkLength;
            if (chunkOffset + chunkLength > _fileLength) {
                chunkLength = (size_t)(_fileLength - chunkOffset);
            }
                    
            chunk = [[FICImageTableChunk alloc] initWithFileDescriptor:_fileDescriptor index:index length:chunkLength];
            [self _setChunk:chunk index:index];
        }
        
        if (chunk != nil) {
            static const NSInteger __recentChunksToKeepMapped = 2;
            [_recentChunks insertObject:chunk atIndex:0];
            
            if ([_recentChunks count] > __recentChunksToKeepMapped) {
                [_recentChunks removeLastObject];
            }            
        }
    }
    
    return chunk;
}

#pragma mark - Storing, Retrieving, and Deleting Entries

- (void)setEntryForEntityUUID:(NSUUID *)entityUUID sourceImageUUID:(NSUUID *)sourceImageUUID imageDrawingBlock:(FICEntityImageDrawingBlock)imageDrawingBlock {
    if (entityUUID != nil && sourceImageUUID != nil && imageDrawingBlock != NULL) {
        [_lock lock];
        
        NSInteger newEntryIndex = [self _indexOfEntryForEntityUUID:entityUUID];
        if (newEntryIndex == NSNotFound) {
            newEntryIndex = [self _nextEntryIndex];
            
            if (newEntryIndex >= _entryCount) {
                NSInteger maximumEntryCount = [_imageFormat maximumCount];
                NSInteger newEntryCount = MIN(maximumEntryCount, _entryCount + MAX(_entriesPerChunk, newEntryIndex - _entryCount + 1));
                [self _setEntryCount:newEntryCount];
            }
        }
        
        if (newEntryIndex < _entryCount) {
            CGSize pixelSize = [_imageFormat pixelSize];
            CGBitmapInfo bitmapInfo = [_imageFormat bitmapInfo];
            CGColorSpaceRef colorSpace = [_imageFormat isGrayscale] ? CGColorSpaceCreateDeviceGray() : CGColorSpaceCreateDeviceRGB();
            NSInteger bitsPerComponent = [_imageFormat bitsPerComponent];
            
            // Create context whose backing store *is* the mapped file data
            FICImageTableEntry *entryData = [self _entryDataAtIndex:newEntryIndex];
            CGContextRef context = CGBitmapContextCreate([entryData bytes], pixelSize.width, pixelSize.height, bitsPerComponent, _imageRowLength, colorSpace, bitmapInfo);
            CGColorSpaceRelease(colorSpace);
            
            CGContextTranslateCTM(context, 0, pixelSize.height);
            CGContextScaleCTM(context, _screenScale, -_screenScale);
            
            // Call drawing block to allow client to draw into the context
            imageDrawingBlock(context, [_imageFormat imageSize]);
            CGContextRelease(context);
            
            [entryData setEntityUUIDBytes:FICUUIDBytesWithUUID(entityUUID)];
            [entryData setSourceImageUUIDBytes:FICUUIDBytesWithUUID(sourceImageUUID)];
            
            // Update our book-keeping
            [_indexMap setObject:[NSNumber numberWithUnsignedInteger:newEntryIndex] forKey:entityUUID];
            [_occupiedIndexes addIndex:newEntryIndex];
            [_sourceImageMap setObject:sourceImageUUID forKey:entityUUID];
            
            // Update MRU array
            [self _entryWasAccessedWithEntityUUID:entityUUID];
            [self saveMetadata];
            
            // Write the data back to the filesystem
            [entryData flush];
        }
        
        [_lock unlock];
    }
}

- (UIImage *)newImageForEntityUUID:(NSUUID *)entityUUID sourceImageUUID:(NSUUID *)sourceImageUUID {
    UIImage *image = nil;
    
    if (entityUUID != nil && sourceImageUUID != nil) {
        [_lock lock];

        FICImageTableEntry *entryData = [self _entryDataForEntityUUID:entityUUID];
        if (entryData != nil) {
            NSUUID *entryEntityUUID = FICUUIDWithUUIDBytes([entryData entityUUIDBytes]);
            NSUUID *entrySourceImageUUID = FICUUIDWithUUIDBytes([entryData sourceImageUUIDBytes]);
            BOOL entityUUIDIsCorrect = entityUUID == nil || [entityUUID isEqual:entryEntityUUID];
            BOOL sourceImageUUIDIsCorrect = sourceImageUUID == nil || [sourceImageUUID isEqual:entrySourceImageUUID];
            
            if (entityUUIDIsCorrect == NO || sourceImageUUIDIsCorrect == NO) {
                // The UUIDs don't match, so we need to invalidate the entry.
                [self deleteEntryForEntityUUID:entityUUID];
                [self saveMetadata];
            } else {
                [self _entryWasAccessedWithEntityUUID:entityUUID];
                
                // Create CGImageRef whose backing store *is* the mapped image table entry. We avoid a memcpy this way.
                CGDataProviderRef dataProvider = CGDataProviderCreateWithData((__bridge_retained void *)entryData, [entryData bytes], [entryData imageLength], _FICReleaseImageData);
                
                CGSize pixelSize = [_imageFormat pixelSize];
                CGBitmapInfo bitmapInfo = [_imageFormat bitmapInfo];
                NSInteger bitsPerComponent = [_imageFormat bitsPerComponent];
                NSInteger bitsPerPixel = [_imageFormat bytesPerPixel] * 8;
                CGColorSpaceRef colorSpace = [_imageFormat isGrayscale] ? CGColorSpaceCreateDeviceGray() : CGColorSpaceCreateDeviceRGB();

                CGImageRef imageRef = CGImageCreate(pixelSize.width, pixelSize.height, bitsPerComponent, bitsPerPixel, _imageRowLength, colorSpace, bitmapInfo, dataProvider, NULL, false, (CGColorRenderingIntent)0);
                CGDataProviderRelease(dataProvider);
                CGColorSpaceRelease(colorSpace);
                
                if (imageRef != NULL) {
                    image = [[UIImage alloc] initWithCGImage:imageRef scale:_screenScale orientation:UIImageOrientationUp];
                    CGImageRelease(imageRef);
                } else {
                    NSString *message = [NSString stringWithFormat:@"*** FIC Error: %s could not create a new CGImageRef for entity UUID %@.", __PRETTY_FUNCTION__, entityUUID];
                    [[FICImageCache sharedImageCache] _logMessage:message];
                }
            }
        }
        
        [_lock unlock];
    }
    
    return image;
}

static void _FICReleaseImageData(void *info, const void *data, size_t size) {
    CFRelease(info);
}

- (void)deleteEntryForEntityUUID:(NSUUID *)entityUUID {
    if (entityUUID != nil) {
        [_lock lock];
        
        NSInteger index = [self _indexOfEntryForEntityUUID:entityUUID];
        if (index != NSNotFound) {
            [_sourceImageMap removeObjectForKey:entityUUID];
            [_indexMap removeObjectForKey:entityUUID];
            [_occupiedIndexes removeIndex:index];
            NSInteger index = [_MRUEntries indexOfObject:entityUUID];
            if (index != NSNotFound) {
                [_MRUEntries removeObjectAtIndex:index];
            }
        }
        
        [_lock unlock];
    }
}

#pragma mark - Checking for Entry Existence

- (BOOL)entryExistsForEntityUUID:(NSUUID *)entityUUID sourceImageUUID:(NSUUID *)sourceImageUUID {
    BOOL imageExists = NO;

    [_lock lock];
    
    FICImageTableEntry *entryData = [self _entryDataForEntityUUID:entityUUID];
    if (entryData != nil && sourceImageUUID != nil) {
        NSUUID *existingEntityUUID = FICUUIDWithUUIDBytes([entryData entityUUIDBytes]);
        BOOL entityUUIDIsCorrect = [entityUUID isEqual:existingEntityUUID];
        
        NSUUID *existingSourceImageUUID = FICUUIDWithUUIDBytes([entryData sourceImageUUIDBytes]);
        BOOL sourceImageUUIDIsCorrect = [sourceImageUUID isEqual:existingSourceImageUUID];
        
        if (entityUUIDIsCorrect == NO || sourceImageUUIDIsCorrect == NO) {
            // The source image UUIDs don't match, so the image data should be deleted for this entity.
            [self deleteEntryForEntityUUID:entityUUID];
            [self saveMetadata];
            entryData = nil;
        }
    }
    
    [_lock unlock];
    
    imageExists = entryData != nil;
    
    return imageExists;
}

#pragma mark - Working with Entries

- (void)_setEntryCount:(NSInteger)entryCount {
    if (entryCount != _entryCount) {        
        off_t fileLength = entryCount * _entryLength;
        int result = ftruncate(_fileDescriptor, fileLength);
        
        if (result != 0) {
            NSString *message = [NSString stringWithFormat:@"*** FIC Error: %s ftruncate returned %d, error = %d, fd = %d, filePath = %@, length = %lld", __PRETTY_FUNCTION__, result, errno, _fileDescriptor, _filePath, fileLength];
            [[FICImageCache sharedImageCache] _logMessage:message];
        } else {
            _fileLength = fileLength;
            _entryCount = entryCount;
            _chunkCount = _entriesPerChunk > 0 ? ((_entryCount + _entriesPerChunk - 1) / _entriesPerChunk) : 0;
        }
    }
}

- (FICImageTableEntry *)_entryDataAtIndex:(NSInteger)index {
    FICImageTableEntry *entryData = nil;
    
    [_lock lock];
    
    if (index < _entryCount) {
        off_t entryOffset = index * _entryLength;
        size_t chunkIndex = (size_t)(entryOffset / _chunkLength);
        
        FICImageTableChunk *chunk = [self _chunkAtIndex:chunkIndex];
        if (chunk != nil) {
            off_t chunkOffset = chunkIndex * _chunkLength;
            off_t entryOffsetInChunk = entryOffset - chunkOffset;
            void *mappedChunkAddress = [chunk bytes];
            void *mappedEntryAddress = mappedChunkAddress + entryOffsetInChunk;
            entryData = [[FICImageTableEntry alloc] initWithImageTableChunk:chunk bytes:mappedEntryAddress length:_entryLength];
        }
    }
    
    [_lock unlock];
    
    return entryData;
}

- (NSInteger)_nextEntryIndex {
    NSMutableIndexSet *unoccupiedIndexes = [[NSMutableIndexSet alloc] initWithIndexesInRange:NSMakeRange(0, _entryCount)];
    [unoccupiedIndexes removeIndexes:_occupiedIndexes];
    
    NSInteger index = [unoccupiedIndexes firstIndex];
    if (index == NSNotFound) {
        index = _entryCount;
    }
    
    if (index >= [_imageFormat maximumCount] && [_MRUEntries count]) {
        // Evict the oldest/least-recently accessed entry here
        [self deleteEntryForEntityUUID:[_MRUEntries lastObject]];
        index = [self _nextEntryIndex];
    }
    
    return index;
}

- (NSInteger)_indexOfEntryForEntityUUID:(NSUUID *)entityUUID {
    NSInteger index = NSNotFound;
    if (_indexMap != nil && entityUUID != nil) {
        NSNumber *indexNumber = [_indexMap objectForKey:entityUUID];
        index = indexNumber ? [indexNumber integerValue] : NSNotFound;
        
        if (index != NSNotFound && index >= _entryCount) {
            [_indexMap removeObjectForKey:entityUUID];
            [_occupiedIndexes removeIndex:index];
            [_sourceImageMap removeObjectForKey:entityUUID];
            index = NSNotFound;
        }
    }

    return index;
}

- (FICImageTableEntry *)_entryDataForEntityUUID:(NSUUID *)entityUUID {
    FICImageTableEntry *entryData = nil;
    NSInteger index = [self _indexOfEntryForEntityUUID:entityUUID];
    if (index != NSNotFound) {
        entryData = [self _entryDataAtIndex:index];
    }
    
    return entryData;
}

- (void)_entryWasAccessedWithEntityUUID:(NSUUID *)entityUUID {
    // Update MRU array
    NSInteger index = [_MRUEntries indexOfObject:entityUUID];
    if (index == NSNotFound) {
        [_MRUEntries insertObject:entityUUID atIndex:0];
    } else if (index != 0) {
        [_MRUEntries removeObjectAtIndex:index];
        [_MRUEntries insertObject:entityUUID atIndex:0];
    }
}

#pragma mark - Working with Metadata

- (void)saveMetadata {
    [_lock lock];
    
    NSDictionary *metadataDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
        _indexMap, FICImageTableIndexMapKey,
        _sourceImageMap, FICImageTableContextMapKey,
        _MRUEntries, FICImageTableMRUArrayKey,
        _imageFormatDictionary, FICImageTableFormatKey, nil];
    
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:metadataDictionary];
    BOOL fileWriteResult = [data writeToFile:[self metadataFilePath] atomically:NO];
    if (fileWriteResult == NO) {
        NSString *message = [NSString stringWithFormat:@"*** FIC Error: %s couldn't write metadata for format %@", __PRETTY_FUNCTION__, [_imageFormat name]];
        [[FICImageCache sharedImageCache] _logMessage:message];
    }

    [_lock unlock];
}

- (void)_loadMetadata {
    NSString *metadataFilePath = [[_filePath stringByDeletingPathExtension] stringByAppendingPathExtension:FICImageTableMetadataFileExtension];
    NSData *metadataData = [NSData dataWithContentsOfMappedFile:metadataFilePath];
    if (metadataData != nil) {
        NSDictionary *metadataDictionary = (NSDictionary *)[NSKeyedUnarchiver unarchiveObjectWithData:metadataData];
        NSDictionary *formatDictionary = [metadataDictionary objectForKey:FICImageTableFormatKey];
        if ([formatDictionary isEqualToDictionary:_imageFormatDictionary] == NO) {
            // Something about this image format has changed, so the existing metadata is no longer valid. The image table file
            // must be deleted and recreated.
            [[NSFileManager defaultManager] removeItemAtPath:_filePath error:NULL];
            [[NSFileManager defaultManager] removeItemAtPath:metadataFilePath error:NULL];
            metadataDictionary = nil;
            
            NSString *message = [NSString stringWithFormat:@"*** FIC Notice: Image format %@ has changed; deleting data and starting over.", [_imageFormat name]];
            [[FICImageCache sharedImageCache] _logMessage:message];
        }
        
        [_indexMap setDictionary:[metadataDictionary objectForKey:FICImageTableIndexMapKey]];
        
        for (NSNumber *index in [_indexMap allValues]) {
            [_occupiedIndexes addIndex:[index intValue]];
        }
        
        [_sourceImageMap setDictionary:[metadataDictionary objectForKey:FICImageTableContextMapKey]];
        _MRUEntries = [[metadataDictionary objectForKey:FICImageTableMRUArrayKey] mutableCopy];
    }
}

#pragma mark - Resetting the Image Table

- (void)reset {
    [_lock lock];
    
    [_indexMap removeAllObjects];
    [_occupiedIndexes removeAllIndexes];
    [_MRUEntries removeAllObjects];
    [_sourceImageMap removeAllObjects];
    
    [self _setEntryCount:0];
    [self saveMetadata];
    
    [_lock unlock];
}

@end
