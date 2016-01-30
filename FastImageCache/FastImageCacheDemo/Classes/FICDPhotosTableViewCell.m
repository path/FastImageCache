//
//  FICDPhotosTableViewCell.m
//  FastImageCacheDemo
//
//  Copyright (c) 2013 Path, Inc.
//  See LICENSE for full license agreement.
//

#import "FICDPhotosTableViewCell.h"
#import "FICDPhoto.h"
#import "FICImageCache.h"
#import "FICDAppDelegate.h"

#pragma mark Class Extension

@interface FICDPhotosTableViewCell () <UIGestureRecognizerDelegate> {
    __weak id <FICDPhotosTableViewCellDelegate> _delegate;
    BOOL _usesImageTable;
    NSArray *_photos;
    NSString *_imageFormatName;
    
    NSMutableArray *_imageViews;
    UITapGestureRecognizer *_tapGestureRecognizer;
}

@end

#pragma mark

@implementation FICDPhotosTableViewCell

@synthesize delegate = _delegate;
@synthesize usesImageTable = _usesImageTable;
@synthesize photos = _photos;
@synthesize imageFormatName = _imageFormatName;

#pragma mark - Property Accessors

- (void)setPhotos:(NSArray *)photos {
    if (photos != _photos) {
        _photos = [photos copy];
        
        // Either create the image views for this cell or clear them out if they already exist
        if (_imageViews == nil) {
            NSInteger photosPerRow = [[self class] photosPerRow];
            _imageViews = [[NSMutableArray alloc] initWithCapacity:photosPerRow];
            
            for (NSInteger i = 0; i < photosPerRow; i++) {
                UIImageView *imageView = [[UIImageView alloc] init];
                [imageView setContentMode:UIViewContentModeScaleAspectFill];
                [_imageViews addObject:imageView];
            }
        } else {
            for (UIImageView *imageView in _imageViews) {
                [imageView setImage:nil];
                [imageView removeFromSuperview];
            }
        }
        
        NSInteger photosCount = [_photos count];
        for (NSInteger i = 0; i < photosCount; i++) {
            FICDPhoto *photo = [_photos objectAtIndex:i];
            UIImageView *imageView = [_imageViews objectAtIndex:i];
            
            if (_usesImageTable) {
                [[FICImageCache sharedImageCache] retrieveImageForEntity:photo withFormatName:_imageFormatName completionBlock:^(id<FICEntity> entity, NSString *formatName, UIImage *image) {
                    // This completion block may be called much later. We should check to make sure this cell hasn't been reused for different photos before displaying the image that has loaded.
                    if (photos == [self photos]) {
                        [imageView setImage:image];
                    }
                }];
            } else {
                [imageView setImage:[photo thumbnailImage]];
            }
        }
        
        [self setNeedsLayout];
    }
}

#pragma mark - Class-Level Definitions

+ (NSString *)reuseIdentifier {
    static NSString *__reuseIdentifier = nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        __reuseIdentifier = NSStringFromClass([FICDPhotosTableViewCell class]);
    });

    return __reuseIdentifier;
}

+ (NSInteger)photosPerRow {
    NSInteger photosPerRow = ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) ? 9 : 4;
    
    return photosPerRow;
}

+ (CGFloat)outerPadding {
    CGFloat outerPadding = ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) ? 10 : 4;
    
    return outerPadding;
}

+ (CGFloat)rowHeight {
    CGFloat rowHeight = ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) ? 84 : 79;
    
    return rowHeight;
}

#pragma mark - Object Lifecycle

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    
    if (self != nil) {
        _tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(_tapGestureRecognizerStateDidChange)];
        [self addGestureRecognizer:_tapGestureRecognizer];
    }
    
    return self;
}

- (id)init {
    return [self initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
}

- (void)dealloc {
    [_tapGestureRecognizer setDelegate:nil];
}

#pragma mark - Configuring the View Hierarchy

- (void)layoutSubviews {
    [super layoutSubviews];
    
    CGFloat innerPadding = ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) ? 9 : 4;
    CGFloat outerPadding = [[self class] outerPadding];
    
    CGRect imageViewFrame = CGRectMake(outerPadding, outerPadding, FICDPhotoSquareImageSize.width, FICDPhotoSquareImageSize.height);
    
    UIView *contentView = [self contentView];
    NSInteger count = [_photos count];
    
    for (NSInteger i = 0; i < count; i++) {
        UIImageView *imageView = [_imageViews objectAtIndex:i];
        [imageView setFrame:imageViewFrame];
        [contentView addSubview:imageView];

        imageViewFrame.origin.x += imageViewFrame.size.width + innerPadding;
    }
}

#pragma mark - Responding to User Interaction Events

- (void)_tapGestureRecognizerStateDidChange {
    if ([_tapGestureRecognizer state] == UIGestureRecognizerStateEnded) {
        CGPoint tapLocationInSelf = [_tapGestureRecognizer locationInView:self];
        UIImageView *selectedImageView = nil;
        
        for (UIImageView *imageView in _imageViews) {
            CGRect imageViewFrame = [imageView frame];
            BOOL frameContainsTapLocation = CGRectContainsPoint(imageViewFrame, tapLocationInSelf);
            
            if (frameContainsTapLocation) {
                selectedImageView = imageView;
            }
        }
        
        if (selectedImageView != nil) {
            NSUInteger imageViewIndex = [_imageViews indexOfObject:selectedImageView];
            FICDPhoto *selectedPhoto = [_photos objectAtIndex:imageViewIndex];
            
            [_delegate photosTableViewCell:self didSelectPhoto:selectedPhoto withImageView:selectedImageView];
        }
    }
}

@end
