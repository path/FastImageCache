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
#import <libkern/OSAtomic.h>

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
    
    NSMutableDictionary *_chunkDictionary;
    NSCountedSet *_chunkSet;
    
    NSRecursiveLock *_lock;
    CFMutableDictionaryRef _indexNumbers;
    
    // Image table metadata
    NSMutableDictionary *_indexMap;         // Key: entity UUID, value: integer index into the table file
    NSMutableDictionary *_sourceImageMap;   // Key: entity UUID, value: source image UUID
    NSMutableIndexSet *_occupiedIndexes;
    NSMutableOrderedSet *_MRUEntries;
    NSCountedSet *_inUseEntries;
    NSDictionary *_imageFormatDictionary;
    int32_t _metadataVersion;

    NSString *_fileDataProtectionMode;
    BOOL _canAccessData;
}

@property (nonatomic, weak) FICImageCache *imageCache;

@end

#pragma mark

@implementation FICImageTable

@synthesize imageFormat =_imageFormat;

#pragma mark - Property Accessors (Public)

- (NSString *)tableFilePath {
    NSString *tableFilePath = [[_imageFormat name] stringByAppendingPathExtension:FICImageTableFileExtension];
    tableFilePath = [[self directoryPath] stringByAppendingPathComponent:tableFilePath];
    
    return tableFilePath;
}

- (NSString *)metadataFilePath {
    NSString *metadataFilePath = [[_imageFormat name] stringByAppendingPathExtension:FICImageTableMetadataFileExtension];
    metadataFilePath = [[self directoryPath] stringByAppendingPathComponent:metadataFilePath];
    
    return metadataFilePath;
}

- (NSString *) directoryPath {
    NSString *directoryPath = [FICImageTable directoryPath];
    if (self.imageCache.nameSpace) {
        directoryPath = [directoryPath stringByAppendingPathComponent:self.imageCache.nameSpace];
    }
    return directoryPath;
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

- (instancetype)initWithFormat:(FICImageFormat *)imageFormat imageCache:(FICImageCache *)imageCache {
    self = [super init];
    
    if (self != nil) {
        if (imageFormat == nil) {
            [NSException raise:NSInvalidArgumentException format:@"*** FIC Exception: %s must pass in an image format.", __PRETTY_FUNCTION__];
        }
        if (imageCache == nil) {
            [NSException raise:NSInvalidArgumentException format:@"*** FIC Exception: %s must pass in an image cache.", __PRETTY_FUNCTION__];
        }
        
        self.imageCache = imageCache;
        
        _lock = [[NSRecursiveLock alloc] init];
        _indexNumbers = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, NULL, &kCFTypeDictionaryValueCallBacks);
        
        _imageFormat = [imageFormat copy];
        _imageFormatDictionary = [imageFormat dictionaryRepresentation];
        
        _screenScale = [[UIScreen mainScreen] scale];
        
        CGSize pixelSize = [_imageFormat pixelSize];
        NSInteger bytesPerPixel = [_imageFormat bytesPerPixel];
        _imageRowLength = (NSInteger)FICByteAlignForCoreAnimation(pixelSize.width * bytesPerPixel);
        _imageLength = _imageRowLength * (NSInteger)pixelSize.height;
        
        _chunkDictionary = [[NSMutableDictionary alloc] init];
        _chunkSet = [[NSCountedSet alloc] init];
        
        _indexMap = [[NSMutableDictionary alloc] init];
        _occupiedIndexes = [[NSMutableIndexSet alloc] init];
        
        _MRUEntries = [[NSMutableOrderedSet alloc] init];
        _inUseEntries = [NSCountedSet set];

        _sourceImageMap = [[NSMutableDictionary alloc] init];
        
        _filePath = [[self tableFilePath] copy];
        
        [self _loadMetadata];
        
        NSString *directoryPath = [self directoryPath];
        
        NSFileManager *fileManager = [[NSFileManager alloc] init];
        
        BOOL isDirectory;
        if (self.imageCache.nameSpace && ![fileManager fileExistsAtPath:directoryPath isDirectory:&isDirectory]) {
            [fileManager createDirectoryAtPath:directoryPath withIntermediateDirectories:YES attributes:nil error:nil];
        }
        
        if ([fileManager fileExistsAtPath:_filePath] == NO) {
            NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
            [attributes setValue:[_imageFormat protectionModeString] forKeyPath:NSFileProtectionKey];
            [fileManager createFileAtPath:_filePath contents:nil attributes:attributes];
        }
       
        NSDictionary *attributes = [fileManager attributesOfItemAtPath:_filePath error:NULL];
        _fileDataProtectionMode = [attributes objectForKey:NSFileProtectionKey];
        
        _fileDescriptor = open([_filePath fileSystemRepresentation], O_RDWR | O_CREAT, 0666);
        
        if (_fileDescriptor >= 0) {
            // The size of each entry in the table needs to be page-aligned. This will cause each entry to have a page-aligned base
            // address, which will help us avoid Core Animation having to copy our images when we eventually set them on layers.
            _entryLength = (NSInteger)FICByteAlign(_imageLength + sizeof(FICImageTableEntryMetadata), [FICImageTable pageSize]);
            
            // Each chunk will map in n entries. Try to keep the chunkLength around 2MB.
            NSInteger goalChunkLength = 2 * (1024 * 1024);
            NSInteger goalEntriesPerChunk = goalChunkLength / _entryLength;
            _entriesPerChunk = MAX(4, goalEntriesPerChunk);
            if ([self _maximumCount] > [_imageFormat maximumCount]) {
                NSString *message = [NSString stringWithFormat:@"*** FIC Warning: growing desired maximumCount (%ld) for format %@ to fill a chunk (%ld)", (long)[_imageFormat maximumCount], [_imageFormat name], (long)[self _maximumCount]];
                [self.imageCache _logMessage:message];
            }
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
            [self.imageCache _logMessage:message];

            self = nil;
        }    
    }
    
    return self;
}

- (void)dealloc {
    if (_fileDescriptor >= 0) {
        close(_fileDescriptor);
    }
}

#pragma mark - Working with Chunks

- (FICImageTableChunk *)_cachedChunkAtIndex:(NSInteger)index {
    return [_chunkDictionary objectForKey:@(index)];
}

- (void)_setChunk:(FICImageTableChunk *)chunk index:(NSInteger)index {
    NSNumber *indexNumber = @(index);
    if (chunk != nil) {
        [_chunkDictionary setObject:chunk forKey:indexNumber];
    } else {
        [_chunkDictionary removeObjectForKey:indexNumber];
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
    }
    
    if (!chunk) {
        NSString *message = [NSString stringWithFormat:@"*** FIC Error: %s failed to get chunk for index %ld.", __PRETTY_FUNCTION__, (long)index];
        [self.imageCache _logMessage:message];
    }
    
    return chunk;
}

#pragma mark - Storing, Retrieving, and Deleting Entries

- (void)setEntryForEntityUUID:(NSString *)entityUUID sourceImageUUID:(NSString *)sourceImageUUID imageDrawingBlock:(FICEntityImageDrawingBlock)imageDrawingBlock {
    if (entityUUID != nil && sourceImageUUID != nil && imageDrawingBlock != NULL) {
        [_lock lock];
        
        NSInteger newEntryIndex = [self _indexOfEntryForEntityUUID:entityUUID];
        if (newEntryIndex == NSNotFound) {
            newEntryIndex = [self _nextEntryIndex];
            
            if (newEntryIndex >= _entryCount) {
                // Determine how many chunks we need to support new entry index.
                // Number of entries should always be a multiple of _entriesPerChunk
                NSInteger numberOfEntriesRequired = newEntryIndex + 1;
                NSInteger newChunkCount = _entriesPerChunk > 0 ? ((numberOfEntriesRequired + _entriesPerChunk - 1) / _entriesPerChunk) : 0;
                NSInteger newEntryCount = newChunkCount * _entriesPerChunk;
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
            if (entryData != nil) {
                [entryData setEntityUUIDBytes:FICUUIDBytesWithString(entityUUID)];
                [entryData setSourceImageUUIDBytes:FICUUIDBytesWithString(sourceImageUUID)];
                
                // Update our book-keeping
                [_indexMap setObject:[NSNumber numberWithUnsignedInteger:newEntryIndex] forKey:entityUUID];
                [_occupiedIndexes addIndex:newEntryIndex];
                [_sourceImageMap setObject:sourceImageUUID forKey:entityUUID];
                
                // Update MRU array
                [self _entryWasAccessedWithEntityUUID:entityUUID];
                [self saveMetadata];
                
                // Unique, unchanging pointer for this entry's index
                NSNumber *indexNumber = [self _numberForEntryAtIndex:newEntryIndex];
                
                // Relinquish the image table lock before calling potentially slow imageDrawingBlock to unblock other FIC operations
                [_lock unlock];
                
                CGContextRef context = CGBitmapContextCreate([entryData bytes], pixelSize.width, pixelSize.height, bitsPerComponent, _imageRowLength, colorSpace, bitmapInfo);
                
                CGContextTranslateCTM(context, 0, pixelSize.height);
                CGContextScaleCTM(context, _screenScale, -_screenScale);
                
                @synchronized(indexNumber) {
                    // Call drawing block to allow client to draw into the context
                    imageDrawingBlock(context, [_imageFormat imageSize]);
                    CGContextRelease(context);
                
                    // Write the data back to the filesystem
                    [entryData flush];
                }
            } else {
                [_lock unlock];
            }
            
            CGColorSpaceRelease(colorSpace);
        } else {
            [_lock unlock];
        }
    }
}

- (UIImage *)newImageForEntityUUID:(NSString *)entityUUID sourceImageUUID:(NSString *)sourceImageUUID preheatData:(BOOL)preheatData {
    UIImage *image = nil;
    
    if (entityUUID != nil && sourceImageUUID != nil) {
        [_lock lock];

        FICImageTableEntry *entryData = [self _entryDataForEntityUUID:entityUUID];
        if (entryData != nil) {
            NSString *entryEntityUUID = FICStringWithUUIDBytes([entryData entityUUIDBytes]);
            NSString *entrySourceImageUUID = FICStringWithUUIDBytes([entryData sourceImageUUIDBytes]);
            BOOL entityUUIDIsCorrect = entityUUID == nil || [entityUUID caseInsensitiveCompare:entryEntityUUID] == NSOrderedSame;
            BOOL sourceImageUUIDIsCorrect = sourceImageUUID == nil || [sourceImageUUID caseInsensitiveCompare:entrySourceImageUUID] == NSOrderedSame;
            
            NSNumber *indexNumber = [self _numberForEntryAtIndex:[entryData index]];
            @synchronized(indexNumber) {
                if (entityUUIDIsCorrect == NO || sourceImageUUIDIsCorrect == NO) {
                    // The UUIDs don't match, so we need to invalidate the entry.
                    [self deleteEntryForEntityUUID:entityUUID];
                } else {
                    [self _entryWasAccessedWithEntityUUID:entityUUID];
                    
                    // Create CGImageRef whose backing store *is* the mapped image table entry. We avoid a memcpy this way.
                    CGDataProviderRef dataProvider = CGDataProviderCreateWithData((__bridge_retained void *)entryData, [entryData bytes], [entryData imageLength], _FICReleaseImageData);
                    
                    [_inUseEntries addObject:entityUUID];
                    __weak FICImageTable *weakSelf = self;
                    [entryData executeBlockOnDealloc:^{
                        [weakSelf removeInUseForEntityUUID:entityUUID];
                    }];
                    
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
                        [self.imageCache _logMessage:message];
                    }
                    
                    if (image != nil && preheatData) {
                        [entryData preheat];
                    }
                }
            }
        }
        
        [_lock unlock];
    }
    
    return image;
}

static void _FICReleaseImageData(void *info, const void *data, size_t size) {
    if (info) {
        CFRelease(info);
    }
}

- (void)removeInUseForEntityUUID:(NSString *)entityUUID {
    [_lock lock];
    [_inUseEntries removeObject:entityUUID];
    [_lock unlock];
}

- (void)deleteEntryForEntityUUID:(NSString *)entityUUID {
    if (entityUUID != nil) {
        [_lock lock];
        
        NSInteger MRUIndex = [_MRUEntries indexOfObject:entityUUID];
        if (MRUIndex != NSNotFound) {
            [_MRUEntries removeObjectAtIndex:MRUIndex];
        }
        
        NSInteger index = [self _indexOfEntryForEntityUUID:entityUUID];
        if (index != NSNotFound) {
            [_sourceImageMap removeObjectForKey:entityUUID];
            [_indexMap removeObjectForKey:entityUUID];
            [_occupiedIndexes removeIndex:index];
            [self saveMetadata];
        }
        
        [_lock unlock];
    }
}

#pragma mark - Checking for Entry Existence

- (BOOL)entryExistsForEntityUUID:(NSString *)entityUUID sourceImageUUID:(NSString *)sourceImageUUID {
    BOOL imageExists = NO;

    [_lock lock];
    
    FICImageTableEntry *entryData = [self _entryDataForEntityUUID:entityUUID];
    if (entryData != nil && sourceImageUUID != nil) {
        NSString *existingEntityUUID = FICStringWithUUIDBytes([entryData entityUUIDBytes]);
        BOOL entityUUIDIsCorrect = [entityUUID isEqualToString:existingEntityUUID];
        
        NSString *existingSourceImageUUID = FICStringWithUUIDBytes([entryData sourceImageUUIDBytes]);
        BOOL sourceImageUUIDIsCorrect = [sourceImageUUID isEqualToString:existingSourceImageUUID];
        
        if (entityUUIDIsCorrect == NO || sourceImageUUIDIsCorrect == NO) {
            // The source image UUIDs don't match, so the image data should be deleted for this entity.
            [self deleteEntryForEntityUUID:entityUUID];
            entryData = nil;
        }
    }
    
    [_lock unlock];
    
    imageExists = entryData != nil;
    
    return imageExists;
}

#pragma mark - Working with Entries

- (NSInteger)_maximumCount {
    return MAX([_imageFormat maximumCount], _entriesPerChunk);
}

- (void)_setEntryCount:(NSInteger)entryCount {
    if (entryCount != _entryCount) {        
        off_t fileLength = entryCount * _entryLength;
        int result = ftruncate(_fileDescriptor, fileLength);
        
        if (result != 0) {
            NSString *message = [NSString stringWithFormat:@"*** FIC Error: %s ftruncate returned %d, error = %d, fd = %d, filePath = %@, length = %lld", __PRETTY_FUNCTION__, result, errno, _fileDescriptor, _filePath, fileLength];
            [self.imageCache _logMessage:message];
        } else {
            _fileLength = fileLength;
            _entryCount = entryCount;
            _chunkCount = _entriesPerChunk > 0 ? ((_entryCount + _entriesPerChunk - 1) / _entriesPerChunk) : 0;
            
            NSDictionary *chunkDictionary = [_chunkDictionary copy];
            for (FICImageTableChunk *chunk in [chunkDictionary allValues]) {
                if ([chunk length] != _chunkLength) {
                    // Issue 31: https://github.com/path/FastImageCache/issues/31
                    // Somehow, we have a partial chunk whose length needs to be adjusted
                    // since we changed our file length.
                    [self _setChunk:nil index:[chunk index]];
                }
            }
        }
    }
}

// There's inherently a race condition between when you ask whether the data is
// accessible and when you try to use that data. Sidestep this issue altogether
// by using NSFileProtectionNone
- (BOOL)canAccessEntryData {
    if ([_fileDataProtectionMode isEqualToString:NSFileProtectionNone])
        return YES;
    
    if ([_fileDataProtectionMode isEqualToString:NSFileProtectionCompleteUntilFirstUserAuthentication] && _canAccessData)
        return YES;
    
    // -[UIApplication isProtectedDataAvailable] checks whether the keybag is locked or not
    UIApplication *application = [UIApplication performSelector:@selector(sharedApplication)];
    if (application) {
        _canAccessData = [application isProtectedDataAvailable];
    }
    
    // We have to fallback to a direct check on the file if either:
    // - The application doesn't exist (happens in some extensions)
    // - The keybag is locked, but the file might still be accessible because the mode is "until first user authentication"
    if (!application || (!_canAccessData && [_fileDataProtectionMode isEqualToString:NSFileProtectionCompleteUntilFirstUserAuthentication])) {
        int fd;
        _canAccessData = ((fd = open([_filePath fileSystemRepresentation], O_RDONLY)) != -1);
        if (_canAccessData)
            close(fd);
    }
    
    return _canAccessData;
}

- (FICImageTableEntry *)_entryDataAtIndex:(NSInteger)index {
    FICImageTableEntry *entryData = nil;
    
    [_lock lock];

    BOOL canAccessData = [self canAccessEntryData];
    if (index < _entryCount && canAccessData) {
        off_t entryOffset = index * _entryLength;
        size_t chunkIndex = (size_t)(entryOffset / _chunkLength);
        
        FICImageTableChunk *chunk = [self _chunkAtIndex:chunkIndex];
        if (chunk != nil) {
            off_t chunkOffset = chunkIndex * _chunkLength;
            off_t entryOffsetInChunk = entryOffset - chunkOffset;
            void *mappedChunkAddress = [chunk bytes];
            void *mappedEntryAddress = mappedChunkAddress + entryOffsetInChunk;
            entryData = [[FICImageTableEntry alloc] initWithImageTableChunk:chunk bytes:mappedEntryAddress length:_entryLength];
            
            if (entryData) {
                [entryData setImageCache:self.imageCache];
                [entryData setIndex:index];
                [_chunkSet addObject:chunk];
            
                __weak FICImageTable *weakSelf = self;
                [entryData executeBlockOnDealloc:^{
                    [weakSelf _entryWasDeallocatedFromChunk:chunk];
                }];
            }
        }
    }
    
    [_lock unlock];
    
    if (!entryData) {
        NSString *message = nil;
        if (canAccessData) {
            message = [NSString stringWithFormat:@"*** FIC Error: %s failed to get entry for index %ld.", __PRETTY_FUNCTION__, (long)index];
        } else {
            message = [NSString stringWithFormat:@"*** FIC Error: %s. Cannot get entry data because imageTable's file has data protection enabled and that data is not currently accessible.", __PRETTY_FUNCTION__];
        }
        [self.imageCache _logMessage:message];
    }
    
    return entryData;
}

- (void)_entryWasDeallocatedFromChunk:(FICImageTableChunk *)chunk {
    [_lock lock];
    [_chunkSet removeObject:chunk];
    if ([_chunkSet countForObject:chunk] == 0) {
        [self _setChunk:nil index:[chunk index]];
    }
    [_lock unlock];
}

- (NSInteger)_nextEntryIndex {
    NSMutableIndexSet *unoccupiedIndexes = [[NSMutableIndexSet alloc] initWithIndexesInRange:NSMakeRange(0, _entryCount)];
    [unoccupiedIndexes removeIndexes:_occupiedIndexes];
    
    NSInteger index = [unoccupiedIndexes firstIndex];
    if (index == NSNotFound) {
        index = _entryCount;
    }
    
    if (index >= [self _maximumCount] && [_MRUEntries count]) {
        // Evict the oldest/least-recently accessed entry here

        NSString *oldestEvictableEntityUUID = [self oldestEvictableEntityUUID];
        if (oldestEvictableEntityUUID) {
            [self deleteEntryForEntityUUID:oldestEvictableEntityUUID];
            index = [self _nextEntryIndex];
        }
    }

    if (index >= [self _maximumCount]) {
        NSString *message = [NSString stringWithFormat:@"FICImageTable - unable to evict entry from table '%@' to make room. New index %ld, desired max %ld", [_imageFormat name], (long)index, (long)[self _maximumCount]];
        [self.imageCache _logMessage:message];
    }
    
    return index;
}

- (NSString *)oldestEvictableEntityUUID {
    NSString *uuid = nil;
    for (NSInteger i = [_MRUEntries count] - 1; i >= 0; i--) {
        NSString *candidateUUID = [_MRUEntries objectAtIndex:i];
        if (![_inUseEntries containsObject:candidateUUID]) {
            uuid = candidateUUID;
            break;
        }
    }

    return uuid;
}

- (NSInteger)_indexOfEntryForEntityUUID:(NSString *)entityUUID {
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

- (FICImageTableEntry *)_entryDataForEntityUUID:(NSString *)entityUUID {
    FICImageTableEntry *entryData = nil;
    NSInteger index = [self _indexOfEntryForEntityUUID:entityUUID];
    if (index != NSNotFound) {
        entryData = [self _entryDataAtIndex:index];
    }
    
    return entryData;
}

- (void)_entryWasAccessedWithEntityUUID:(NSString *)entityUUID {
    // Update MRU array
    NSInteger index = [_MRUEntries indexOfObject:entityUUID];
    if (index == NSNotFound) {
        [_MRUEntries insertObject:entityUUID atIndex:0];
    } else if (index != 0) {
        [_MRUEntries removeObjectAtIndex:index];
        [_MRUEntries insertObject:entityUUID atIndex:0];
    }
}

// Unchanging pointer value for a given entry index to synchronize on
- (NSNumber *)_numberForEntryAtIndex:(NSInteger)index {
    NSNumber *resultNumber = (__bridge id)CFDictionaryGetValue(_indexNumbers, (const void *)index);
    if (!resultNumber) {
        resultNumber = [NSNumber numberWithInteger:index];
        CFDictionarySetValue(_indexNumbers, (const void *)index, (__bridge void *)resultNumber);
    }
    return resultNumber;
}

#pragma mark - Working with Metadata

- (void)saveMetadata {
    @autoreleasepool {
        [_lock lock];
        
        NSDictionary *metadataDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
                                            [_indexMap copy], FICImageTableIndexMapKey,
                                            [_sourceImageMap copy], FICImageTableContextMapKey,
                                            [[_MRUEntries array] copy], FICImageTableMRUArrayKey,
                                            [_imageFormatDictionary copy], FICImageTableFormatKey, nil];

        __block int32_t metadataVersion = OSAtomicIncrement32(&_metadataVersion);

        [_lock unlock];
        
        static dispatch_queue_t __metadataQueue = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            __metadataQueue = dispatch_queue_create("com.path.FastImageCache.ImageTableMetadataQueue", NULL);
        });
        
        dispatch_async(__metadataQueue, ^{
            // Cancel serialization if a new metadata version is queued to be saved
            if (metadataVersion != _metadataVersion) {
                return;
            }

            @autoreleasepool {
                NSData *data = [NSJSONSerialization dataWithJSONObject:metadataDictionary options:kNilOptions error:NULL];

                // Cancel disk writing if a new metadata version is queued to be saved
                if (metadataVersion != _metadataVersion) {
                    return;
                }

                BOOL fileWriteResult = [data writeToFile:[self metadataFilePath] atomically:NO];
                if (fileWriteResult == NO) {
                    NSString *message = [NSString stringWithFormat:@"*** FIC Error: %s couldn't write metadata for format %@", __PRETTY_FUNCTION__, [_imageFormat name]];
                    [self.imageCache _logMessage:message];
                }
            }
        });
    }
}

- (void)_loadMetadata {
    NSString *metadataFilePath = [self metadataFilePath];
    NSData *metadataData = [NSData dataWithContentsOfURL:[NSURL fileURLWithPath:metadataFilePath] options:NSDataReadingMappedAlways error:NULL];
    if (metadataData != nil) {
        NSDictionary *metadataDictionary = (NSDictionary *)[NSJSONSerialization JSONObjectWithData:metadataData options:kNilOptions error:NULL];
        
        if (!metadataDictionary) {
            // The image table was likely previously stored as a .plist
            // We'll read it into memory as a .plist and later store it (during -saveMetadata) using NSJSONSerialization for performance reasons
            metadataDictionary = (NSDictionary *)[NSPropertyListSerialization propertyListWithData:metadataData options:0 format:NULL error:NULL];
        }
        
        NSDictionary *formatDictionary = [metadataDictionary objectForKey:FICImageTableFormatKey];
        if ([formatDictionary isEqualToDictionary:_imageFormatDictionary] == NO) {
            // Something about this image format has changed, so the existing metadata is no longer valid. The image table file
            // must be deleted and recreated.
            [[NSFileManager defaultManager] removeItemAtPath:_filePath error:NULL];
            [[NSFileManager defaultManager] removeItemAtPath:metadataFilePath error:NULL];
            metadataDictionary = nil;
            
            NSString *message = [NSString stringWithFormat:@"*** FIC Notice: Image format %@ has changed; deleting data and starting over.", [_imageFormat name]];
            [self.imageCache _logMessage:message];
        }
        
        [_indexMap setDictionary:[metadataDictionary objectForKey:FICImageTableIndexMapKey]];
        
        for (NSNumber *index in [_indexMap allValues]) {
            [_occupiedIndexes addIndex:[index intValue]];
        }
        
        [_sourceImageMap setDictionary:[metadataDictionary objectForKey:FICImageTableContextMapKey]];
        
        [_MRUEntries removeAllObjects];
        
        NSArray *mruArray = [metadataDictionary objectForKey:FICImageTableMRUArrayKey];
        if (mruArray) {
            [_MRUEntries addObjectsFromArray:mruArray];
        }
    }
}

#pragma mark - Resetting the Image Table

- (void)reset {
    [_lock lock];
    
    [_indexMap removeAllObjects];
    [_occupiedIndexes removeAllIndexes];
    [_inUseEntries removeAllObjects];
    [_MRUEntries removeAllObjects];
    [_sourceImageMap removeAllObjects];
    [_chunkDictionary removeAllObjects];
    [_chunkSet removeAllObjects];
    
    [self _setEntryCount:0];
    [self saveMetadata];
    
    [_lock unlock];
}

@end
