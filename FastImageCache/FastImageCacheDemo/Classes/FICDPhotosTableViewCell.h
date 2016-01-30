//
//  FICDPhotosTableViewCell.h
//  FastImageCacheDemo
//
//  Copyright (c) 2013 Path, Inc.
//  See LICENSE for full license agreement.
//

#import <UIKit/UIKit.h>

@class FICDPhoto;

@protocol FICDPhotosTableViewCellDelegate;

@interface FICDPhotosTableViewCell : UITableViewCell

@property (nonatomic, weak) id <FICDPhotosTableViewCellDelegate> delegate;
@property (nonatomic, assign) BOOL usesImageTable;
@property (nonatomic, copy) NSArray *photos;
@property (nonatomic, copy) NSString *imageFormatName;

+ (NSString *)reuseIdentifier;
+ (NSInteger)photosPerRow;
+ (CGFloat)outerPadding;
+ (CGFloat)rowHeight;

@end

@protocol FICDPhotosTableViewCellDelegate <NSObject>

@required
- (void)photosTableViewCell:(FICDPhotosTableViewCell *)photosTableViewCell didSelectPhoto:(FICDPhoto *)photo withImageView:(UIImageView *)imageView;

@end
