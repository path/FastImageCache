![Fast Image Cache Logo](https://s3.amazonaws.com/fast-image-cache/readme-resources/logo.png)

---
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)

Fast Image Cache is an efficient, persistent, and—above all—fast way to store and retrieve images in your iOS application. Part of any good iOS application's user experience is fast, smooth scrolling, and Fast Image Cache helps make this easier.

A significant burden on performance for graphics-rich applications like [Path](http://www.path.com) is image loading. The traditional method of loading individual images from disk is just too slow, especially while scrolling. Fast Image Cache was created specifically to solve this problem.

## Table of Contents

- [Version History](#version-history)
- [What Fast Image Cache Does](#what-fast-image-cache-does)
- [How Fast Image Cache Works](#how-fast-image-cache-works)
- [Considerations](#considerations)
- [Requirements](#requirements)
- [Getting Started](#getting-started)
    - [Integrating Fast Image Cache](#integrating-fast-image-cache)
    - [Initial Configuration](#initial-configuration)
    - [Requesting Images from the Image Cache](#requesting-images-from-the-image-cache)
    - [Providing Source Images to the Image Cache](#providing-source-images-to-the-image-cache)
    - [Canceling Source Image Requests](#canceling-source-image-requests)
    - [Working with Image Format Families](#working-with-image-format-families)
- [Documentation](#documentation)
- [Demo Application](#demo-application)
- [Contributors](#contributors)
- [Credits](#credits)
- [License](#license)

## Version History

- [**1.0**](https://github.com/path/FastImageCache/releases/tag/1.0)   (10/18/2013): Initial release
- [**1.1**](https://github.com/path/FastImageCache/releases/tag/1.1)   (10/22/2013): Added ARC support and more robust Core Animation byte alignment
- [**1.2**](https://github.com/path/FastImageCache/releases/tag/1.2)   (10/30/2013): Added support for image format styles and canceling image requests
- [**1.3**](https://github.com/path/FastImageCache/releases/tag/1.3)   (03/30/2014): Significant bug fixes and performance improvements

## What Fast Image Cache Does

- Stores images of similar sizes and styles together
- Persists image data to disk
- Returns images to the user significantly faster than traditional methods
- Automatically manages cache expiry based on recency of usage
- Utilizes a model-based approach for storing and retrieving images
- Allows images to be processed on a per-model basis before being stored into the cache

## How Fast Image Cache Works

In order to understand how Fast Image Cache works, it's helpful to understand a typical scenario encountered by many applications that work with images.

### The Scenario

iOS applications, especially those in the social networking space, often have many images to display at once, such as user photos. The intuitive, traditional approach is to request image data from an API, process the original images to create the desired sizes and styles, and store these processed images on the device.

Later, when an application needs to display these images, they are loaded from disk into memory and displayed in an image view or are otherwise rendered to the screen.

### The Problem

It turns out that the process of going from compressed, on-disk image data to a rendered Core Animation layer that the user can actually see is very expensive. As the number of images to be displayed increases, this cost easily adds up to a noticeable degradation in frame rate. And scrollable views further exacerbate the situation because content can change rapidly, requiring fast processing time to maintain a smooth 60FPS.<sup>1</sup>

Consider the workflow that occurs when loading an image from disk and displaying it on screen:

1. [`+[UIImage imageWithContentsOfFile:]`](https://developer.apple.com/library/ios/documentation/uikit/reference/UIImage_Class/Reference/Reference.html#//apple_ref/doc/uid/TP40006890-CH3-SW12) uses [Image I/O](https://developer.apple.com/library/ios/documentation/graphicsimaging/conceptual/ImageIOGuide/imageio_intro/ikpg_intro.html#//apple_ref/doc/uid/TP40005462-CH201-TPXREF101) to create a [`CGImageRef`](http://www.google.com/url?sa=t&rct=j&q=&esrc=s&source=web&cd=1&cad=rja&ved=0CCwQFjAA&url=http%3A%2F%2Fdeveloper.apple.com%2Flibrary%2Fios%2Fdocumentation%2Fgraphicsimaging%2FReference%2FCGImage%2FReference%2Freference.html&ei=fG9XUpX_BqWqigLymIG4BQ&usg=AFQjCNHTelntXU5Gw0BQkQqj9HC5iZibyA&sig2=tLY7PDhyockUVlVFbrzyOQ) from memory-mapped data. At this point, the image has not yet been decoded.
1. The returned image is assigned to a [`UIImageView`](http://www.google.com/url?sa=t&rct=j&q=&esrc=s&source=web&cd=1&cad=rja&ved=0CCwQFjAA&url=http%3A%2F%2Fdeveloper.apple.com%2Flibrary%2Fios%2Fdocumentation%2Fuikit%2Freference%2FUIImageView_Class%2F&ei=VX9YUpGUKcG1iwLN3oHwDg&usg=AFQjCNGJCra_NhnVaXH2_pqIKjIHiNX9zQ&sig2=Lk2CMoN4kO5OzLJYhGh6Uw).
1. An implicit [`CATransaction`](https://www.google.com/url?sa=t&rct=j&q=&esrc=s&source=web&cd=1&cad=rja&ved=0CCwQFjAA&url=https%3A%2F%2Fdeveloper.apple.com%2Flibrary%2Fios%2Fdocumentation%2FGraphicsImaging%2FReference%2FCATransaction_class%2F&ei=AINYUsSqIqPfiAKsk4CoBA&usg=AFQjCNG5CarCxgkwdV_br80YDI7UwMTrmA&sig2=aPE_IoQSPUltdCYqARjt9Q) captures these layer tree modifications.
1. On the next iteration of the main run loop, Core Animation commits the implicit transaction, which may involve creating a copy of any images which have been set as layer contents. Depending on the image, copying it involves some or all of these steps: <sup>2</sup>
    1. Buffers are allocated to manage file IO and decompression operations.
    1. The file data is read from disk into memory.
    1. The compressed image data is decoded into its uncompressed bitmap form, which is typically a very CPU-intensive operation.<sup>3</sup>
    1. The uncompressed bitmap data is then used by Core Animation to render the layer.

**These costs can easily accumulate and kill perceived application performance.** Especially while scrolling, users are presented with an unsatisfying user experience that is not in line with the the overall iOS experience.

---

<sup>1</sup> `60FPS` ≈ `0.01666s per frame` = `16.7ms per frame`. This means that any main-thread work that takes longer than 16ms will cause your application to drop animation frames.

<sup>2</sup> The documentation for [`CALayer`](https://www.google.com/url?sa=t&rct=j&q=&esrc=s&source=web&cd=1&cad=rja&ved=0CCwQFjAA&url=https%3A%2F%2Fdeveloper.apple.com%2Flibrary%2Fios%2Fdocumentation%2Fgraphicsimaging%2Freference%2FCALayer_class%2FIntroduction%2FIntroduction.html&ei=P29XUpj2LeahiALptICgCQ&usg=AFQjCNGwJuHcQV4593kuookUcvNZYTvx5w&sig2=zi1audY4ZsNE_xLeESVD_Q)'s [`contents`](https://developer.apple.com/library/ios/documentation/graphicsimaging/reference/CALayer_class/Introduction/Introduction.html#//apple_ref/doc/uid/TP40004500-CH1-SW24) property states that "assigning a value to this property causes the layer to use your image rather than [creating] a separate backing store." However, the meaning of "use your image" is still vague. Profiling an application using [Instruments](https://developer.apple.com/library/prerelease/content/documentation/DeveloperTools/Conceptual/InstrumentsUserGuide/) often reveals calls to `CA::Render::copy_image`, even when the Core Animation Instrument has indicated that none of the images have been copied. One reason that Core Animation will require a copy of an image is improper [byte alignment](#byte-alignment). 

<sup>3</sup> As of iOS 7, Apple does not make their hardware JPEG decoder available for third-party applications to use. As a result, only a slower, software decoder is used for this step.

### The Solution

Fast Image Cache minimizes (or avoids entirely) much of the work described above using a variety of techniques:

#### Mapped Memory

At the heart of how Fast Image Cache works are image tables. Image tables are similar to [sprite sheets](http://en.wikipedia.org/wiki/Sprite_sheet#Sprites_by_CSS), often used in 2D gaming. An image table packs together images of the same dimensions into a single file. This file is opened once and is left open for reading and writing for as long as an application remains in memory.

Image tables use the [`mmap`](https://developer.apple.com/library/ios/documentation/system/conceptual/manpages_iphoneos/man2/mmap.2.html) system call to directly map file data into memory. No [`memcpy`](https://developer.apple.com/library/ios/documentation/system/conceptual/manpages_iphoneos/man3/memcpy.3.html) occurs. This system call merely creates a mapping between data on disk and a region of memory.

When a request is made to the image cache to return a specific image, the image table finds (in constant time) the location of the desired image data in the file it maintains. That region of file data is mapped into memory, and a new [`CGImageRef`](http://www.google.com/url?sa=t&rct=j&q=&esrc=s&source=web&cd=1&cad=rja&ved=0CCwQFjAA&url=http%3A%2F%2Fdeveloper.apple.com%2Flibrary%2Fios%2Fdocumentation%2Fgraphicsimaging%2FReference%2FCGImage%2FReference%2Freference.html&ei=fG9XUpX_BqWqigLymIG4BQ&usg=AFQjCNHTelntXU5Gw0BQkQqj9HC5iZibyA&sig2=tLY7PDhyockUVlVFbrzyOQ) whose backing store **is** the mapped file data is created.

When the returned [`CGImageRef`](http://www.google.com/url?sa=t&rct=j&q=&esrc=s&source=web&cd=1&cad=rja&ved=0CCwQFjAA&url=http%3A%2F%2Fdeveloper.apple.com%2Flibrary%2Fios%2Fdocumentation%2Fgraphicsimaging%2FReference%2FCGImage%2FReference%2Freference.html&ei=fG9XUpX_BqWqigLymIG4BQ&usg=AFQjCNHTelntXU5Gw0BQkQqj9HC5iZibyA&sig2=tLY7PDhyockUVlVFbrzyOQ) (wrapped into a [`UIImage`](http://www.google.com/url?sa=t&rct=j&q=&esrc=s&source=web&cd=1&cad=rja&ved=0CC0QFjAA&url=http%3A%2F%2Fdeveloper.apple.com%2Flibrary%2Fios%2Fdocumentation%2Fuikit%2Freference%2FUIImage_Class%2F&ei=lG9XUtTdJIm9iwKDq4CACA&usg=AFQjCNEa2LN2puQYOfBRVPaEsvsSawOVMg&sig2=0TzbC6wzT5EdynHsDMIEUw)) is ready to be drawn to the screen, iOS's virtual memory system pages in the actual file data. This is another benefit of using mapped memory; the VM system will automatically handle the memory management for us. In addition, mapped memory "doesn't count" toward an application's real memory usage.

In like manner, when image data is being stored in an image table, a memory-mapped bitmap context is created. Along with the original image, this context is passed to an image table's corresponding entity object. This object is responsible for drawing the image into the current context, optionally further configuring the context (e.g., clipping the context to a rounded rect) or doing any additional drawing (e.g., drawing an overlay image atop the original image). [`mmap`](https://developer.apple.com/library/ios/documentation/system/conceptual/manpages_iphoneos/man2/mmap.2.html) marshals the drawn image data to disk, so no image buffer is allocated in memory.

#### Uncompressed Image Data

In order to avoid expensive image decompression operations, image tables store uncompressed image data in their files. If a source image is compressed, it must first be decompressed for the image table to work with it. **This is a one-time cost.** Furthermore, it is possible to [utilize image format families](#working-with-image-format-families) to perform this decompression exactly once for a collection of similar image formats.

There are obvious consequences to this approach, however. Uncompressed image data requires more disk space, and the difference between compressed and uncompressed file sizes can be significant, especially for image formats like JPEG. For this reason, **Fast Image Cache works best with smaller images**, although there is no API restriction that enforces this.

#### Byte Alignment

For high-performance scrolling, it is critical that Core Animation is able to use an image without first having to create a copy. One of the reasons Core Animation would create a copy of an image is improper byte-alignment of the image's underlying [`CGImageRef`](http://www.google.com/url?sa=t&rct=j&q=&esrc=s&source=web&cd=1&cad=rja&ved=0CCwQFjAA&url=http%3A%2F%2Fdeveloper.apple.com%2Flibrary%2Fios%2Fdocumentation%2Fgraphicsimaging%2FReference%2FCGImage%2FReference%2Freference.html&ei=fG9XUpX_BqWqigLymIG4BQ&usg=AFQjCNHTelntXU5Gw0BQkQqj9HC5iZibyA&sig2=tLY7PDhyockUVlVFbrzyOQ). A properly aligned bytes-per-row value must be a multiple of `8 pixels × bytes per pixel`. For a typical ARGB image, the aligned bytes-per-row value is a multiple of 64. Every image table is configured such that each image is always properly byte-aligned for Core Animation from the start. As a result, when images are retrieved from an image table, they are already in a form that Core Animation can work with directly without having to create a copy.

## Considerations

### Image Table Size

Image tables are configured by image formats, which specify (among other things) the maximum number of entries (i.e., individual images) an image table can have. This is to prevent the size of an image table file from growing arbitrarily.

Image tables allocate 4 bytes per pixel, so the maximum space occupied by an image table file can be determined as follows:

`4 bytes per pixel × image width in pixels × image height in pixels × maximum number of entries`

Applications using Fast Image Cache should carefully consider how many images each image table should contain. When a new image is stored in an image table that is already full, it will replace the least-recently-accessed image.

### Image Table Transience

Image table files are stored in the user's caches directory in a subdirectory called `ImageTables`. iOS can remove cached files at any time to free up disk space, so applications using Fast Image Cache must be able to recreate any stored images and should not rely on image table files persisting forever.

> **Note**: As a reminder, data stored in a user's caches directory is not backed up to iTunes or iCloud.

### Source Image Persistence

Fast Image Cache does not persist the original source images processed by entities to create the image data stored in its image tables.

For example, if an original image is resized by an entity to create a thumbnail to be stored in an image table, it is the application's responsibility to either persist the original image or be able to retrieve or recreate it again.

Image format families can be specified to efficiently make use of a single source image. See [Working with Image Format Families](#working-with-image-format-families) for more information.

### Data Protection

In iOS 4, Apple introduced data protection. When a user's device is locked or turned off, the disk is encrypted. Files written to disk are protected by default, although applications can manually specify the data protection mode for each file it manages. With the advent of new background modes in iOS 7, applications can now execute in the background briefly even while the device is locked. As a result, data protection can cause issues if applications attempt to access files that are encrypted.

Fast Image Cache allows each image format to specify the data protection mode used when creating its backing image table file. Be aware that enabling data protection for image table files means that Fast Image Cache might not be able to read or write image data from or to these files when the disk is encrypted.

## Requirements

Fast Image Cache requires iOS 6.0 or greater and relies on the following frameworks:

- Foundation
- Core Graphics
- UIKit

> **Note**: As of version 1.1, Fast Image Cache **does** use ARC.

---

The `FastImageCacheDemo` Xcode project requires Xcode 5.0 or greater and is configured to deploy against iOS 6.0.

## Getting Started

### Integrating Fast Image Cache

#### CocoaPods

For easy project integration, Fast Image Cache is available as a [CocoaPod](http://cocoapods.org).

#### Manually

- Clone this repository, or [download the latest archive of `master`](https://github.com/path/FastImageCache/archive/master.zip).
- From the `FastImageCache` root directory, copy the source files from the inner [`FastImageCache`](./FastImageCache) subdirectory to your Xcode project.
- Import [`FICImageCache.h`](./FastImageCache/FastImageCache/FastImageCache/FICImageCache.h) wherever you use the image cache.
- Import [`FICEntity.h`](./FastImageCache/FastImageCache/FastImageCache/FICEntity.h) for each class that conforms to [`FICEntity`](https://s3.amazonaws.com/fast-image-cache/documentation/Protocols/FICEntity.html).

### Initial Configuration

Before the image cache can be used, it needs to be configured. This must occur each launch, so the application delegate might be a good place to do this.

#### Creating Image Formats

Each image format corresponds to an image table that the image cache will use. Image formats that can use the same source image to render the images they store in their image tables should belong to the same [image format family](#working-with-image-format-families). See [Image Table Size](#image-table-size) for more information about how to determine an appropriate maximum count.

```objective-c
static NSString *XXImageFormatNameUserThumbnailSmall = @"com.mycompany.myapp.XXImageFormatNameUserThumbnailSmall";
static NSString *XXImageFormatNameUserThumbnailMedium = @"com.mycompany.myapp.XXImageFormatNameUserThumbnailMedium";
static NSString *XXImageFormatFamilyUserThumbnails = @"com.mycompany.myapp.XXImageFormatFamilyUserThumbnails";

FICImageFormat *smallUserThumbnailImageFormat = [[FICImageFormat alloc] init];
smallUserThumbnailImageFormat.name = XXImageFormatNameUserThumbnailSmall;
smallUserThumbnailImageFormat.family = XXImageFormatFamilyUserThumbnails;
smallUserThumbnailImageFormat.style = FICImageFormatStyle16BitBGR;
smallUserThumbnailImageFormat.imageSize = CGSizeMake(50, 50);
smallUserThumbnailImageFormat.maximumCount = 250;
smallUserThumbnailImageFormat.devices = FICImageFormatDevicePhone;
smallUserThumbnailImageFormat.protectionMode = FICImageFormatProtectionModeNone;

FICImageFormat *mediumUserThumbnailImageFormat = [[FICImageFormat alloc] init];
mediumUserThumbnailImageFormat.name = XXImageFormatNameUserThumbnailMedium;
mediumUserThumbnailImageFormat.family = XXImageFormatFamilyUserThumbnails;
mediumUserThumbnailImageFormat.style = FICImageFormatStyle32BitBGRA;
mediumUserThumbnailImageFormat.imageSize = CGSizeMake(100, 100);
mediumUserThumbnailImageFormat.maximumCount = 250;
mediumUserThumbnailImageFormat.devices = FICImageFormatDevicePhone;
mediumUserThumbnailImageFormat.protectionMode = FICImageFormatProtectionModeNone;

NSArray *imageFormats = @[smallUserThumbnailImageFormat, mediumUserThumbnailImageFormat];
```

An image format's style effectively determines the bit depth of the images stored in an image table. The following styles are currently available:

- 32-bit color plus an alpha component (default)
- 32-bit color, no alpha component
- 16-bit color, no alpha component
- 8-bit grayscale, no alpha component

If the source images lack transparency (e.g., JPEG images), then better Core Animation performance can be achieved by using 32-bit color with no alpha component. If the source images have little color detail, or if the image format's image size is relatively small, it may be sufficient to use 16-bit color with little or no perceptible loss of quality. This results in smaller image table files stored on disk.

#### Configuring the Image Cache

Once one or more image formats have been defined, they need to be assigned to the image cache. Aside from assigning the image cache's delegate, there is nothing further that can be configured on the image cache itself.

```objective-c
FICImageCache *sharedImageCache = [FICImageCache sharedImageCache];
sharedImageCache.delegate = self;
sharedImageCache.formats = imageFormats;
```

#### Creating Entities

Entities are objects that conform to the [`FICEntity`](https://s3.amazonaws.com/fast-image-cache/documentation/Protocols/FICEntity.html) protocol. Entities uniquely identify entries in an image table, and they are also responsible for drawing the images they wish to store in the image cache. Applications that already have model objects defined (perhaps managed by Core Data) are usually appropriate entity candidates.

```objective-c
@interface XXUser : NSObject <FICEntity>

@property (nonatomic, assign, getter = isActive) BOOL active;
@property (nonatomic, copy) NSString *userID;
@property (nonatomic, copy) NSURL *userPhotoURL;

@end
```

Here is an example implementation of the [`FICEntity`](https://s3.amazonaws.com/fast-image-cache/documentation/Protocols/FICEntity.html) protocol.

```objective-c
- (NSString *)UUID {
    CFUUIDBytes UUIDBytes = FICUUIDBytesFromMD5HashOfString(_userID);
    NSString *UUID = FICStringWithUUIDBytes(UUIDBytes);

    return UUID;
}

- (NSString *)sourceImageUUID {
    CFUUIDBytes sourceImageUUIDBytes = FICUUIDBytesFromMD5HashOfString([_userPhotoURL absoluteString]);
    NSString *sourceImageUUID = FICStringWithUUIDBytes(sourceImageUUIDBytes);

    return sourceImageUUID;
}

- (NSURL *)sourceImageURLWithFormatName:(NSString *)formatName {
    return _sourceImageURL;
}

- (FICEntityImageDrawingBlock)drawingBlockForImage:(UIImage *)image withFormatName:(NSString *)formatName {
    FICEntityImageDrawingBlock drawingBlock = ^(CGContextRef context, CGSize contextSize) {
        CGRect contextBounds = CGRectZero;
        contextBounds.size = contextSize;
        CGContextClearRect(context, contextBounds);

        // Clip medium thumbnails so they have rounded corners
        if ([formatName isEqualToString:XXImageFormatNameUserThumbnailMedium]) {
            UIBezierPath clippingPath = [self _clippingPath];
            [clippingPath addClip];
        }
        
        UIGraphicsPushContext(context);
        [image drawInRect:contextBounds];
        UIGraphicsPopContext();
    };
    
    return drawingBlock;
}
```

Ideally, an entity's [`UUID`](https://s3.amazonaws.com/fast-image-cache/documentation/Protocols/FICEntity.html#//api/name/UUID) should never change. This is why it corresponds nicely with a model object's server-generated ID in the case where an application is working with resources retrieved from an API.

An entity's [`sourceImageUUID`](https://s3.amazonaws.com/fast-image-cache/documentation/Protocols/FICEntity.html#//api/name/sourceImageUUID) *can* change. For example, if a user updates their profile photo, the URL to that photo should change as well. The [`UUID`](https://s3.amazonaws.com/fast-image-cache/documentation/Protocols/FICEntity.html#//api/name/UUID) remains the same and identifies the same user, but the changed profile photo URL will indicate that there is a new source image.

> **Note**: Often, it is best to hash whatever identifiers are being used to define [`UUID`](https://s3.amazonaws.com/fast-image-cache/documentation/Protocols/FICEntity.html#//api/name/UUID) and [`sourceImageUUID`](https://s3.amazonaws.com/fast-image-cache/documentation/Protocols/FICEntity.html#//api/name/sourceImageUUID). Fast Image Cache provides utility functions to do this. Because hashing can be expensive, it is recommended that the hash be computed only once (or only when the identifier changes) and stored in an instance variable.

When the image cache is asked to provide an image for a particular entity and format name, the entity is responsible for providing a URL. The URL need not even point to an actual resource—e.g., the URL might be constructed of a custom URL-scheme—, but it must be a valid URL.

The image cache uses these URLs merely to keep track of which image requests are already in flight; multiple requests to the image cache for the same image are handled correctly without any wasted effort. The choice to use URLs as a basis for keying image cache requests actually complements many real-world application designs whereby URLs to image resources (rather than the images themselves) are included with server-provided model data.

> **Note**: Fast Image Cache does not provide any mechanism for making network requests. This is the responsibility of the image cache's delegate.

Finally, once the source image is available, the entity is asked to provide a drawing block. The image table that will store the final image sets up a file-mapped bitmap context and invokes the entity's drawing block. This makes it convenient for each entity to decide how to process the source image for particular image formats.

### Requesting Images from the Image Cache

Fast Image Cache works under the on-demand, lazy-loading design pattern common to Cocoa.

```objective-c
XXUser *user = [self _currentUser];
NSString *formatName = XXImageFormatNameUserThumbnailSmall;
FICImageCacheCompletionBlock completionBlock = ^(id <FICEntity> entity, NSString *formatName, UIImage *image) {
    _imageView.image = image;
    [_imageView.layer addAnimation:[CATransition animation] forKey:kCATransition];
};

BOOL imageExists = [sharedImageCache retrieveImageForEntity:user withFormatName:formatName completionBlock:completionBlock];
    
if (imageExists == NO) {
    _imageView.image = [self _userPlaceholderImage];
}
```

There are a few things to note here.

1. Note that it is an entity and an image format name that uniquely identifies the desired image in the image cache. As a format name uniquely identifies an image table, the entity alone uniquely identifies the desired image data in an image table.
1. The image cache never returns a [`UIImage`](http://www.google.com/url?sa=t&rct=j&q=&esrc=s&source=web&cd=1&cad=rja&ved=0CC0QFjAA&url=http%3A%2F%2Fdeveloper.apple.com%2Flibrary%2Fios%2Fdocumentation%2Fuikit%2Freference%2FUIImage_Class%2F&ei=lG9XUtTdJIm9iwKDq4CACA&usg=AFQjCNEa2LN2puQYOfBRVPaEsvsSawOVMg&sig2=0TzbC6wzT5EdynHsDMIEUw) directly. The requested image is included in the completion block. The return value will indicate whether or not the image already exists in the image cache.
1. [`-retrieveImageForEntity:withFormatName:completionBlock:`](https://s3.amazonaws.com/fast-image-cache/documentation/Classes/FICImageCache.html#//api/name/retrieveImageForEntity:withFormatName:completionBlock:) is a synchronous method. If the requested image already exists in the image cache, the completion block will be called immediately. There is an asynchronous counterpart to this method called [`-asynchronouslyRetrieveImageForEntity:withFormatName:completionBlock:`](https://s3.amazonaws.com/fast-image-cache/documentation/Classes/FICImageCache.html#//api/name/asynchronouslyRetrieveImageForEntity:withFormatName:completionBlock:).
1. If a requested image does **not** already exist in the image cache, then the image cache invokes the necessary actions to request the source image for its delegate. Afterwards, perhaps some time later, the completion block will be called.

> **Note**: The distinction of synchronous and asynchronous only applies to the process of retrieving an image that already exists in the image cache. In the case where a synchronous image request is made for an image that does not already exist in the image case, the image cache does **not** block the calling thread until it has an image. The retrieval method will immediately return `NO`, and the completion block will be called later.
>
> See the [`FICImageCache`](https://s3.amazonaws.com/fast-image-cache/documentation/Classes/FICImageCache.html) class header for a thorough explanation of how the execution lifecycle works for image retrieval, especially as it relates to the handling of the completion blocks.

### Providing Source Images to the Image Cache

There are two ways to provide source images to the image cache.

1. **On Demand**: This is the preferred method. The image cache's delegate is responsible for supplying the image cache with source images.

    ```objective-c
    - (void)imageCache:(FICImageCache *)imageCache wantsSourceImageForEntity:(id<FICEntity>)entity withFormatName:(NSString *)formatName completionBlock:(FICImageRequestCompletionBlock)completionBlock {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            // Fetch the desired source image by making a network request
            NSURL *requestURL = [entity sourceImageURLWithFormatName:formatName];
            UIImage *sourceImage = [self _sourceImageForURL:requestURL];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                completionBlock(sourceImage);
            });
        });
    }    
    ```
    
    This is where the URL-based nature of how the image cache manages image requests is convenient. First, an image retrieval request to the image cache for an image that is already being handled by the image cache's delegate—e.g., waiting on a large image to be downloaded—is simply added to the first request's array of completion blocks. Second, if source images are downloaded from the Internet (as is often the case), the URL for such a network request is readily available.
    
    > **Note**: The completion block must be called on the main thread. Fast Image Cache is architected such that this call will not block the main thread, as processing sources image is handled in the image cache's own serial dispatch queue.

2. **Manually**: It is possible to manually insert image data into the image cache.

    ```objective-c
    // Just finished downloading new user photo
    
    XXUser *user = [self _currentUser];
    NSString *formatName = XXImageFormatNameUserThumbnailSmall;
    FICImageCacheCompletionBlock completionBlock = ^(id <FICEntity> entity, NSString *formatName, UIImage *image) {
        NSLog(@"Processed and stored image for entity: %@", entity);
    };
    
    [sharedImageCache setImage:newUserPhoto forEntity:user withFormatName:formatName completionBlock:completionBlock];
    ```
    
> **Note**: Fast Image Cache does **not** persist source images. See [Source Image Persistence](#source-image-persistence) for more information.

### Canceling Source Image Requests

If an image request is already in progress, it can be cancelled:

```objective-c
// We scrolled up far enough that the image we requested in no longer visible; cancel the request
XXUser *user = [self _currentUser];
NSString *formatName = XXImageFormatNameUserThumbnailSmall;
[sharedImageCache cancelImageRetrievalForEntity:user withFormatName:formatName];
```

When this happens, Fast Image Cache cleans up its internal bookkeeping, and any completion blocks from the corresponding image request will do nothing at this point. However, the image cache's delegate is still responsible for ensuring that any outstanding source image requests (e.g., network requests) are cancelled:

```objective-c
- (void)imageCache:(FICImageCache *)imageCache cancelImageLoadingForEntity:(id <FICEntity>)entity withFormatName:(NSString *)formatName {
    [self _cancelNetworkRequestForSourceImageForEntity:entity withFormatName:formatName];
}
```

### Working with Image Format Families

The advantage of classifying image formats into families is that the image cache's delegate can tell the image cache to process entity source images for **all** image formats in a family when **any** image format in that family is processed. By default, all image formats are processed for a given family unless you implement this delegate and return otherwise. 

```objective-c
- (BOOL)imageCache:(FICImageCache *)imageCache shouldProcessAllFormatsInFamily:(NSString *)formatFamily forEntity:(id<FICEntity>)entity {
    BOOL shouldProcessAllFormats = NO;

    if ([formatFamily isEqualToString:XXImageFormatFamilyUserThumbnails]) {
        XXUser *user = (XXUser *)entity;
        shouldProcessAllFormats = user.active;
    }

    return shouldProcessAllFormats;
}
```

The advantage of processing all image formats in a family at once is that the source image does not need to be repeatedly downloaded (or loaded into memory if cached on disk).

For example, if a user changes their profile photo, it probably makes sense to process the new source image for every variant at the same time that the first image format is processed. That is, if the image cache is processing a new user profile photo for the image format named `XXImageFormatNameUserThumbnailSmall`, then it makes sense to also process and store new image data for that same user for the image format named `XXImageFormatNameUserThumbnailMedium`.

## Documentation

Fast Image Cache's header files are fully documented, and [appledoc](http://gentlebytes.com/appledoc/) can be used to generate documentation in various forms, including HTML and Xcode DocSet.

HTML documentation can be [found here](https://s3.amazonaws.com/fast-image-cache/documentation/index.html).

## Demo Application

Included with this repository is a demo app Xcode project. It demonstrates the difference between the conventional approach for loading and displaying images and the Fast Image Cache approach. See the [requirements for running the demo app Xcode project](#requirements).

> **Note**: The demo application must either be supplied with JPEG images, or the included [`fetch_demo_images.sh`](./FastImageCache/FastImageCacheDemo/fetch_demo_images.sh) script in the [`FastImageCacheDemo`](./FastImageCache/FastImageCacheDemo) directory must be run.

### Video

<p align="center">
    <a href="https://s3.amazonaws.com/fast-image-cache/readme-resources/demo-app-video.html"><img src="https://s3.amazonaws.com/fast-image-cache/readme-resources/demo-app-video-placeholder.png" alt="Fast Image Cache Demo App Video"></a>
</p>

> **Note**: In this demo video, the first demonstrated method is the conventional approach. The second method is using image tables.

### Statistics

The following statistics were measured from a run of the demo application:

| Method           | Scrolling Performance   | Disk Usage   | [RPRVT](http://www.mikeash.com/pyblog/friday-qa-2009-06-19-mac-os-x-process-memory-statistics.html)<sup>1</sup>
| ---------------- |:-----------------------:|:------------:|:-----------------------------:|
| Conventional     | `~35FPS`                | `568KB`      | `2.40MB`: `1.06MB` + `1.34MB` |
| Fast Image Cache | `~59FPS`                | `2.2MB`      | `1.15MB`: `1.06MB` + `0.09MB` |

The takeaway is that Fast Image Cache sacrifices disk usage to achieve a faster framerate and overall less memory usage.

---
<sup>1</sup> The first value is the the total RPRVT used by a method to display a screen's worth of JPEG thumbnails. The second value is the baseline RPRVT where all the table view cells and image views are on screen, but none of the image views have images set. The third value is how much additional RPRVT each method used beyond the baseline.

## Contributors

<a href="https://twitter.com/mallorypaine" target="_blank"><img src="http://www.gravatar.com/avatar/76db5d6bdcb64ac9e86e6a521ab57f03.jpg?s=85" alt="Mallory Paine"></a>  
**Mallory Paine** — Author and Original API Design  
<a href="https://twitter.com/mallorypaine" target="_blank">@mallorypaine</a>

---

<a href="https://twitter.com/LucasTizma" target="_blank"><img src="http://www.gravatar.com/avatar/2005b2ed368913850076bb52cee79713.jpg?s=85" alt="Michael Potter"></a>  
**Michael Potter** — Documentation and API Refactoring  
<a href="https://twitter.com/LucasTizma" target="_blank">@LucasTizma</a>

## Credits

- All [demo application](#demo-application) photos were taken from [morgueFile](http://www.morguefile.com) and are used according to the [morgueFile license](http://www.morguefile.com/license/full).
- Fast Image Cache logo illustration by the amazing [Jake Mix](https://twitter.com/jakemix).

## License

Fast Image Cache is made available under the [MIT license](http://opensource.org/licenses/MIT):

<pre>
The MIT License (MIT)

Copyright (c) 2013 Path, Inc.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
</pre>
