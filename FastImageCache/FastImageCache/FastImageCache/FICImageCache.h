//
//  FICImageCache.h
//  FastImageCache
//
//  Copyright (c) 2013 Path, Inc.
//  See LICENSE for full license agreement.
//

#import "FICImports.h"
#import "FICImageFormat.h"
#import "FICEntity.h"

@protocol FICEntity;
@protocol FICImageCacheDelegate;

typedef void (^FICImageCacheCompletionBlock)(id <FICEntity> _Nullable entity, NSString * _Nonnull formatName, UIImage * _Nullable image);
typedef void (^FICImageRequestCompletionBlock)(UIImage * _Nullable sourceImage);

NS_ASSUME_NONNULL_BEGIN

/**
 `FICImageCache` is the primary class for managing and interacting with the image cache. Applications using the image cache create one or more `<FICImageFormat>`
 objects. These formats effectively act as logical groupings for image data stored in the image cache. An `<FICImageTable>` object is created for each format defined by
 your application to allow for efficient storage and retrieval of image data. Image data is keyed off of objects conforming to the `<FICEntity>` protocol as well as an
 image format name.
 */
@interface FICImageCache : NSObject

/**
 The namespace of the image cache.
 
 @discussion Namespace is responsible for isolation of dirrerent image cache instances on file system level. Namespace should be unique across application.
 */

@property (readonly, nonatomic) NSString *nameSpace;

///----------------------------
/// @name Managing the Delegate
///----------------------------

/**
 The delegate of the image cache.
 
 @discussion The delegate is responsible for asynchronously providing the source image for an entity. Optionally, the delegate can require that all formats in a format
 family for a particular entity be processed. Any errors that occur in the image cache are also communicated back to the delegate.
 */
@property (nonatomic, weak) id <FICImageCacheDelegate> delegate;

///---------------------------------------
/// @name Creating Image Cache instances
///---------------------------------------

/**
 Returns new image cache.
 
 @return A new instance of `FICImageCache`.
 
 @param nameSpace The namespace that uniquely identifies current image cahce entity. If no nameSpace given, default namespace will be used.
 
 @note Fast Image Cache can either be used as a singleton for convenience or can exist as multiple instances. 
 However, all instances of `FICImageCache` will make use same dispatch queue. To separate location on disk for storing image tables namespaces are used.
 
 @see [FICImageCache dispatchQueue]
 */

- (instancetype)initWithNameSpace:(NSString *)nameSpace;

///---------------------------------------
/// @name Accessing the Shared Image Cache
///---------------------------------------

/**
 Returns the shared image cache.
 
 @return A shared instance of `FICImageCache`.
 
 @note Shared instance always binded to default namespace.
 
 @see [FICImageCache dispatchQueue]
 */
+ (instancetype)sharedImageCache;

/**
 Returns the shared dispatch queue used by all instances of `FICImageCache`.
 
 @return A generic, shared dispatch queue of type `dispatch_queue_t`.
 
 @note All instances of `FICImageCache` make use a single, shared dispatch queue to do their work.
 */
+ (dispatch_queue_t)dispatchQueue;

///---------------------------------
/// @name Working with Image Formats
///---------------------------------

/**
 Sets the image formats to be used by the image cache.
 
 @param formats An array of `<FICImageFormat>` objects.
 
 @note Once the image formats have been set, subsequent calls to this method will do nothing.
 */
- (void)setFormats:(NSArray<FICImageFormat*> *)formats;

/**
 Returns an image format previously associated with the image cache.
 
 @param formatName The name of the image format to return.
 
 @return An image format with the name `formatName` or `nil` if no format with that name exists.
 */
- (nullable FICImageFormat *)formatWithName:(NSString *)formatName;

/**
 Returns all the image formats of the same family previously associated with the image cache.
 
 @param family The name of the family of image formats to return.
 
 @return An array of `<FICImageFormat>` objects whose family is `family` or `nil` if no format belongs to that family.
 */
- (nullable NSArray<FICImageFormat *> *)formatsWithFamily:(NSString *)family;

///-----------------------------------------------
/// @name Storing, Retrieving, and Deleting Images
///-----------------------------------------------

/**
 Manually sets the the image to be used by the image cache for a particular entity and format name.
 
 @discussion Usually the image cache's delegate is responsible for lazily providing the source image for a given entity. This source image is then processed according
 to the drawing block defined by an entity for a given image format. This method allows the sender to explicitly set the image data to be stored in the image cache.
 After the image has been processed by the image cache, the completion block is called asynchronously on the main queue.
 
 @param image The image to store in the image cache.
 
 @param entity The entity that uniquely identifies the source image.
 
 @param formatName The format name that uniquely identifies which image table to look in for the cached image.
 
 @param completionBlock The completion block that is called after the image has been processed or if an error occurs.
 
 The completion block's type is defined as follows:
     
     typedef void (^FICImageCacheCompletionBlock)(id <FICEntity> entity, NSString *formatName, UIImage *image)
 */
- (void)setImage:(UIImage *)image forEntity:(id <FICEntity>)entity withFormatName:(NSString *)formatName completionBlock:(nullable FICImageCacheCompletionBlock)completionBlock;

/**
 Attempts to synchronously retrieve an image from the image cache.
 
 @param entity The entity that uniquely identifies the source image.
 
 @param formatName The format name that uniquely identifies which image table to look in for the cached image. Must not be nil.
 
 @param completionBlock The completion block that is called when the requested image is available or if an error occurs.
 
 The completion block's type is defined as follows:
     
     typedef void (^FICImageCacheCompletionBlock)(id <FICEntity> entity, NSString *formatName, UIImage *image)
     
 If the requested image already exists in the image cache, then the completion block is immediately called synchronously on the current thread. If the requested image
 does not already exist in the image cache, then the completion block will be called asynchronously on the main thread as soon as the requested image is available.
     
 @return `YES` if the requested image already exists in the image case, `NO` if the image needs to be provided to the image cache by its delegate.
 
 @discussion Even if you make a synchronous image retrieval request, if the image does not yet exist in the image cache, the delegate will be asked to provide a source
 image, and it will be processed. This always occurs asynchronously. In this case, the return value from this method will be `NO`, and the image will be available in the
 completion block.
 
 @note You can always rely on the completion block being called. If an error occurs for any reason, the `image` parameter of the completion block will be `nil`. See
 <[FICImageCacheDelegate imageCache:errorDidOccurWithMessage:]> for information about being notified when errors occur.
 */
- (BOOL)retrieveImageForEntity:(id <FICEntity>)entity withFormatName:(NSString *)formatName completionBlock:(nullable FICImageCacheCompletionBlock)completionBlock;

/**
 Asynchronously retrieves an image from the image cache.
 
 @param entity The entity that uniquely identifies the source image.
 
 @param formatName The format name that uniquely identifies which image table to look in for the cached image. Must not be nil.
 
 @param completionBlock The completion block that is called when the requested image is available or if an error occurs.
 
 The completion block's type is defined as follows:
 
     typedef void (^FICImageCacheCompletionBlock)(id <FICEntity> entity, NSString *formatName, UIImage *image)
 
 Unlike its synchronous counterpart, this method will always call its completion block asynchronously on the main thread, even if the request image is already in the
 image cache.
 
 @return `YES` if the requested image already exists in the image case, `NO` if the image needs to be provided to the image cache by its delegate.
 
 @note You can always rely on the completion block being called. If an error occurs for any reason, the `image` parameter of the completion block will be `nil`. See
 <[FICImageCacheDelegate imageCache:errorDidOccurWithMessage:]> for information about being notified when errors occur.
 
 @see [FICImageCache retrieveImageForEntity:withFormatName:completionBlock:]
 */
- (BOOL)asynchronouslyRetrieveImageForEntity:(id <FICEntity>)entity withFormatName:(NSString *)formatName completionBlock:(nullable FICImageCacheCompletionBlock)completionBlock;

/**
 Deletes an image from the image cache.
 
 @param entity The entity that uniquely identifies the source image.
 
 @param formatName The format name that uniquely identifies which image table to look in for the cached image.
 */
- (void)deleteImageForEntity:(id <FICEntity>)entity withFormatName:(NSString *)formatName;

///-------------------------------
/// @name Canceling Image Requests
///-------------------------------

/**
 Cancels an active request for an image from the image cache.
 
 @param entity The entity that uniquely identifies the source image.
 
 @param formatName The format name that uniquely identifies which image table to look in for the cached image.
 
 @discussion After this method is called, the completion block of the <[FICImageCacheDelegate imageCache:wantsSourceImageForEntity:withFormatName:completionBlock:]> delegate
 method for the corresponding entity, if called, does nothing.
 */
- (void)cancelImageRetrievalForEntity:(id <FICEntity>)entity withFormatName:(NSString *)formatName;
    
///-----------------------------------
/// @name Checking for Image Existence
///-----------------------------------

/**
 Returns whether or not an image exists in the image cache.
 
 @param entity The entity that uniquely identifies the source image.
 
 @param formatName The format name that uniquely identifies which image table to look in for the cached image.
 
 @return `YES` if an image exists in the image cache for a given entity and format name. Otherwise, `NO`.
 */
- (BOOL)imageExistsForEntity:(id <FICEntity>)entity withFormatName:(NSString *)formatName;

///--------------------------------
/// @name Resetting the Image Cache
///--------------------------------

/**
 Resets the image cache by deleting all image tables and their contents.
 
 @note Resetting an image cache does not reset its image formats.
 */
- (void)reset;

@end

/**
 `FICImageCacheDelegate` defines the required and optional actions that an image cache's delegate can perform.
 */
@protocol FICImageCacheDelegate <NSObject>

@optional

/**
 This method is called on the delegate when the image cache needs a source image.
 
 @param imageCache The image cache that is requesting the source image.
 
 @param entity The entity that uniquely identifies the source image.
 
 @param formatName The format name that uniquely identifies which image table to look in for the cached image.
 
 @param completionBlock The completion block that the receiver must call when it has a source image ready.
 
 The completion block's type is defined as follows:
 
     typedef void (^FICImageRequestCompletionBlock)(UIImage *sourceImage)
     
 The completion block must always be called on the main thread.
 
 @discussion A source image is usually the original, full-size image that represents an entity. This source image is processed for every unique format to create the
 actual image data to be stored in the image cache. This method is an asynchronous data provider, so nothing is actually returned to the sender. Instead, the delegate's
 implementation is expected to call the completion block once an image is available.
 
 Fast Image Cache is architected under the typical design pattern whereby model objects provide a URL to certain image assets and allow the client to actually retrieve
 the images via network requests only when needed. As a result, the implementation of this method will usually involve creating an asynchronous network request using
 the URL returned by <[FICEntity sourceImageURLWithFormatName:]>, deserializing the image data when the request completes, and finally calling this method's completion
 block to provide the image cache with the source image.
 */
- (void)imageCache:(FICImageCache *)imageCache wantsSourceImageForEntity:(id <FICEntity>)entity withFormatName:(NSString *)formatName completionBlock:(nullable FICImageRequestCompletionBlock)completionBlock;

/**
 This method is called on the delegate when the image cache has received an image retrieval cancellation request.
 
 @param imageCache The image cache that has received the image retrieval cancellation request.
 
 @param entity The entity that uniquely identifies the source image.
 
 @param formatName The format name that uniquely identifies which image table to look in for the cached image.
 
 @discussion When an image retrieval cancellation request is made to the image cache, it removes all of its internal bookkeeping for requests. However, it is still the
 delegate's responsibility to cancel whatever logic is it performing to provide a source image to the cache (e.g., a network request).
 
 @see [FICImageCache cancelImageRetrievalForEntity:withFormatName:]
 */
- (void)imageCache:(FICImageCache *)imageCache cancelImageLoadingForEntity:(id <FICEntity>)entity withFormatName:(NSString *)formatName;

/**
 This method is called on the delegate to determine whether or not all formats in a family should be processed right now.
 
 @note If this method is not implemented by the delegate, the default value is `YES`.
 
 @param imageCache The image cache that is requesting the source image.
 
 @param formatFamily The name of a format family.
 
 @param entity The entity that uniquely identifies the source image.
 
 @return `YES` if all formats in a format family should be processed. Otherwise, `NO`.
 
 @discussion This method is called whenever new image data is stored in the image cache. Because format families are used to group multiple different formats together,
 typically the delegate will want to return `YES` here so that other formats in the same family can be processed.
 
 For example, if your image cache has defined several different thumbnail sizes and styles for a person model, and if a person changes their profile photo, you would
 want every thumbnail size and style is updated with the new source image.
 */
- (BOOL)imageCache:(FICImageCache *)imageCache shouldProcessAllFormatsInFamily:(NSString *)formatFamily forEntity:(id <FICEntity>)entity;

/**
 This method is called on the delegate whenever the image cache has an error message to log.
 
 @param imageCache The image cache that is requesting the source image.
 
 @param errorMessage The error message generated by the image cache.
 
 @discussion Fast Image Cache will not explicitly log any messages to standard output. Instead, it allows the delegate to handle (or ignore) any error output.
 */
- (void)imageCache:(FICImageCache *)imageCache errorDidOccurWithMessage:(NSString *)errorMessage;

@end

NS_ASSUME_NONNULL_END