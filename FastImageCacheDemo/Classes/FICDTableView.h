//
//  FICDTableView.h
//  FastImageCacheDemo
//
//  Copyright (c) 2013 Path, Inc.
//  See LICENSE for full license agreement.
//

@interface FICDTableView : UITableView

@property (nonatomic, assign, readonly) CGFloat averageFPS;

- (void)resetScrollingPerformanceCounters;

@end
