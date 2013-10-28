//
//  FICDFullscreenPhotoDisplayController.m
//  FastImageCacheDemo
//
//  Copyright (c) 2013 Path, Inc.
//  See LICENSE for full license agreement.
//

#import "FICDFullscreenPhotoDisplayController.h"
#import "FICDPhoto.h"

#import <CoreImage/CoreImage.h>

#pragma mark Class Extension

@interface FICDFullscreenPhotoDisplayController () <UIGestureRecognizerDelegate> {
    __weak id <FICDFullscreenPhotoDisplayControllerDelegate> _delegate;
    BOOL _delegateImplementsWillShowSourceImageForPhotoWithThumbnailImageView;
    BOOL _delegateImplementsDidShowSourceImageForPhotoWithThumbnailImageView;
    BOOL _delegateImplementsWillHideSourceImageForPhotoWithThumbnailImageView;
    BOOL _delegateImplementsDidHideSourceImageForPhotoWithThumbnailImageView;
    
    UIView *_fullscreenView;
    UIView *_backgroundView;
    
    UIImageView *_thumbnailImageView;
    CGRect _originalThumbnailImageViewFrame;
    NSUInteger _originalThumbnailImageViewSubviewIndex;
    UIView *_originalThumbnailImageViewSuperview;
    
    UIImageView *_sourceImageView;
    FICDPhoto *_photo;
    
    UITapGestureRecognizer *_tapGestureRecognizer;
    
    CIContext* _CoreImageContext;
}

@end

#pragma mark

@implementation FICDFullscreenPhotoDisplayController

@synthesize delegate = _delegate;

#pragma mark - Property Accessors

- (void)setDelegate:(id<FICDFullscreenPhotoDisplayControllerDelegate>)delegate {
    _delegate = delegate;
    
    _delegateImplementsWillShowSourceImageForPhotoWithThumbnailImageView = [_delegate respondsToSelector:@selector(photoDisplayController:willShowSourceImage:forPhoto:withThumbnailImageView:)];
    _delegateImplementsDidShowSourceImageForPhotoWithThumbnailImageView = [_delegate respondsToSelector:@selector(photoDisplayController:didShowSourceImage:forPhoto:withThumbnailImageView:)];
    _delegateImplementsWillHideSourceImageForPhotoWithThumbnailImageView = [_delegate respondsToSelector:@selector(photoDisplayController:willHideSourceImage:forPhoto:withThumbnailImageView:)];
    _delegateImplementsDidHideSourceImageForPhotoWithThumbnailImageView = [_delegate respondsToSelector:@selector(photoDisplayController:didHideSourceImage:forPhoto:withThumbnailImageView:)];
}

- (BOOL)isDisplayingPhoto {
    return _photo != nil;
}

#pragma mark - Object Lifecycle

+ (instancetype)sharedDisplayController {
    static FICDFullscreenPhotoDisplayController *__sharedDisplayController = nil;
    
    if (__sharedDisplayController == nil) {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            __sharedDisplayController = [[[self class] alloc] init];
        });
    }
    
    return __sharedDisplayController;
}

- (id)init {
    self = [super init];
    
    if (self != nil) {
        UIViewAutoresizing autoresizingMask = (UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight);
        
        _fullscreenView = [[UIView alloc] init];
        [_fullscreenView setAutoresizingMask:autoresizingMask];
        
        _backgroundView = [[UIView alloc] init];
        [_backgroundView setAutoresizingMask:autoresizingMask];
        [_backgroundView setBackgroundColor:[UIColor colorWithWhite:0 alpha:0.8]];
        
        _sourceImageView = [[UIImageView alloc] init];
        [_sourceImageView setAutoresizingMask:autoresizingMask];
        [_sourceImageView setContentMode:UIViewContentModeScaleAspectFill];
        [_sourceImageView setClipsToBounds:YES];
        
        _tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(_tapGestureRecognizerStateDidChange)];
        [_fullscreenView addGestureRecognizer:_tapGestureRecognizer];
        
        _CoreImageContext = [CIContext contextWithOptions:nil];
    }
    
    return self;
}

- (void)dealloc {
    [_tapGestureRecognizer setDelegate:nil];
}

#pragma mark - Showing and Hiding a Fullscreen Photo

- (void)showFullscreenPhoto:(FICDPhoto *)photo forImageFormatName:(NSString *)imageFormatName withThumbnailImageView:(UIImageView *)thumbnailImageView {
    // Stash away the photo
    _photo = photo;

    // Stash away original thumbnail image view information
    _thumbnailImageView = thumbnailImageView;
    _originalThumbnailImageViewSuperview = [thumbnailImageView superview];
    _originalThumbnailImageViewFrame = [thumbnailImageView frame];
    _originalThumbnailImageViewSubviewIndex = [[[thumbnailImageView superview] subviews] indexOfObject:thumbnailImageView];
    
    // Configure the fullscreen view
    UIView *rootViewControllerView = [[[[UIApplication sharedApplication] keyWindow] rootViewController] view];
    [_fullscreenView setFrame:[rootViewControllerView bounds]];
    [rootViewControllerView addSubview:_fullscreenView];
    
    // Configure the background view
    [_backgroundView setFrame:[_fullscreenView bounds]];
    [_backgroundView setAlpha:0];
    [_fullscreenView addSubview:_backgroundView];
    
    // Configure the thumbnail image view
    CGRect convertedThumbnailImageViewFrame = [_originalThumbnailImageViewSuperview convertRect:_originalThumbnailImageViewFrame toView:_fullscreenView];
    [_thumbnailImageView setFrame:convertedThumbnailImageViewFrame];
    [_fullscreenView addSubview:_thumbnailImageView];
    
    // Configure the source image view
    UIImage *sourceImage = [photo sourceImage];
    
    // Desaturate the source image with Core Image if the image format name is FICDPhotoSquareImage8BitGrayscaleFormatName
    if ([imageFormatName isEqualToString:FICDPhotoSquareImage8BitGrayscaleFormatName]) {
        CIFilter *colorControlsFilter = [CIFilter filterWithName:@"CIColorControls"];
        [colorControlsFilter setValue:[CIImage imageWithCGImage:[sourceImage CGImage]] forKey:kCIInputImageKey];
        [colorControlsFilter setValue:[NSNumber numberWithFloat:0] forKey:@"inputSaturation"];
        
        CIImage *outputCIImage = [colorControlsFilter outputImage];
        CGImageRef outputImageRef = [_CoreImageContext createCGImage:outputCIImage fromRect:[outputCIImage extent]];
        sourceImage = [UIImage imageWithCGImage:outputImageRef];
        
        CGImageRelease(outputImageRef);
    }
    
    [_sourceImageView setImage:sourceImage];
    [_sourceImageView setFrame:convertedThumbnailImageViewFrame];
    [_sourceImageView setAlpha:0];
    [_fullscreenView addSubview:_sourceImageView];
    
    // Inform the delegate that we're about to show a fullscreen photo
    if (_delegateImplementsWillShowSourceImageForPhotoWithThumbnailImageView) {
        [_delegate photoDisplayController:self willShowSourceImage:sourceImage forPhoto:_photo withThumbnailImageView:_thumbnailImageView];
    }
    
    // Animate fullscreen photo appearance
    [UIView animateWithDuration:0.3 animations:^{
        [_backgroundView setAlpha:1];
        [_thumbnailImageView setFrame:[_fullscreenView bounds]];
        [_sourceImageView setAlpha:1];
        [_sourceImageView setFrame:[_fullscreenView bounds]];
    } completion:^(BOOL finished) {
        // Inform the delegate that we just showed a fullscreen photo
        if (_delegateImplementsDidShowSourceImageForPhotoWithThumbnailImageView) {
            [_delegate photoDisplayController:self didShowSourceImage:sourceImage forPhoto:_photo withThumbnailImageView:_thumbnailImageView];
        }
    }];
}

- (void)hideFullscreenPhoto {
    UIImage *sourceImage = [_sourceImageView image];
    // Inform the delegate that we're about to hide a fullscreen photo
    if (_delegateImplementsWillHideSourceImageForPhotoWithThumbnailImageView) {
        [_delegate photoDisplayController:self willHideSourceImage:sourceImage forPhoto:_photo withThumbnailImageView:_thumbnailImageView];
    }

    CGRect convertedThumbnailImageViewFrame = [_originalThumbnailImageViewSuperview convertRect:_originalThumbnailImageViewFrame toView:_fullscreenView];

    // Animate fullscreen photo appearance
    [UIView animateWithDuration:0.3 animations:^{
        [_backgroundView setAlpha:0];
        [_thumbnailImageView setFrame:convertedThumbnailImageViewFrame];
        [_sourceImageView setAlpha:0];
        [_sourceImageView setFrame:convertedThumbnailImageViewFrame];
    } completion:^(BOOL finished) {
        [_thumbnailImageView setFrame:_originalThumbnailImageViewFrame];
        [_originalThumbnailImageViewSuperview insertSubview:_thumbnailImageView atIndex:_originalThumbnailImageViewSubviewIndex];
        
        [_fullscreenView removeFromSuperview];
        
        // Inform the delegate that we just hide a fullscreen photo
        if (_delegateImplementsDidHideSourceImageForPhotoWithThumbnailImageView) {
            [_delegate photoDisplayController:self didHideSourceImage:sourceImage forPhoto:_photo withThumbnailImageView:_thumbnailImageView];
        }
        
        // Clean up
        _photo = nil;
        
        _thumbnailImageView = nil;
        _originalThumbnailImageViewSuperview = nil;
        
        _originalThumbnailImageViewFrame = CGRectZero;
        _originalThumbnailImageViewSubviewIndex = 0;
        
        _sourceImageView.image = nil;
    }];
}

- (void)_tapGestureRecognizerStateDidChange {
    if ([_tapGestureRecognizer state] == UIGestureRecognizerStateEnded) {
        [self hideFullscreenPhoto];
    }
}

@end
