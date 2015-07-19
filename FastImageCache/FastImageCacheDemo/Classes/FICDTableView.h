//
//  FICDTableView.h
//  FastImageCacheDemo
//
//  Copyright (c) 2013 Path, Inc.
//  See LICENSE for full license agreement.
//

#import <UIKit/UIKit.h>

@interface FICDTableView : UITableView

@property (nonatomic, assign, readonly) CGFloat averageFPS;

- (void)resetScrollingPerformanceCounters;

@end
