//
//  FICDTableView.m
//  FastImageCacheDemo
//
//  Copyright (c) 2013 Path, Inc.
//  See LICENSE for full license agreement.
//

#import "FICDTableView.h"

#pragma mark Class Extension

@interface FICDTableView () {
    CADisplayLink *_displayLink;
    NSInteger _framesInLastInterval;
    CFAbsoluteTime _lastLogTime;
    NSInteger _totalFrames;
    NSTimeInterval _scrollingTime;
    CGFloat _averageFPS;
}

@property (nonatomic, assign, readwrite) CGFloat averageFPS;

@end

#pragma mark

@implementation FICDTableView

@synthesize averageFPS = _averageFPS;

#pragma mark - Object Lifecycle

- (void)dealloc {
    [_displayLink invalidate];
}

- (void)didMoveToWindow {
    if ([self window] != nil) {
        [self _scrollingStatusDidChange];
    } else {
         [_displayLink invalidate];
        _displayLink = nil;
    }
}

#pragma mark - Monitoring Scrolling Performance

- (void)resetScrollingPerformanceCounters {
    _framesInLastInterval = 0;
    _lastLogTime = CFAbsoluteTimeGetCurrent();
    _scrollingTime = 0;
    _totalFrames = 0;
}

- (void)_scrollingStatusDidChange {
    NSString *currentRunLoopMode = [[NSRunLoop currentRunLoop] currentMode];
    BOOL isScrolling = [currentRunLoopMode isEqualToString:UITrackingRunLoopMode];
    
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_scrollingStatusDidChange) object:nil];
    
    if (isScrolling) {
        if (_displayLink == nil) {
            _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(_screenDidUpdateWhileScrolling:)];
            [_displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:UITrackingRunLoopMode];
        }
        
        _framesInLastInterval = 0;
        _lastLogTime = CFAbsoluteTimeGetCurrent();
        [_displayLink setPaused:NO];
        
        // Let us know when scrolling has stopped
        [self performSelector:@selector(_scrollingStatusDidChange) withObject:nil afterDelay:0 inModes:[NSArray arrayWithObject:NSDefaultRunLoopMode]];
    } else {
        [_displayLink setPaused:YES];
        
        // Let us know when scrolling begins
        [self performSelector:@selector(_scrollingStatusDidChange) withObject:nil afterDelay:0 inModes:[NSArray arrayWithObject:UITrackingRunLoopMode]];
    }
}

- (void)_screenDidUpdateWhileScrolling:(CADisplayLink *)displayLink {
    CFAbsoluteTime currentTime = CFAbsoluteTimeGetCurrent();
    if (!_lastLogTime) {
        _lastLogTime = currentTime;
    }
    CGFloat delta = currentTime - _lastLogTime;
    if (delta >= 1) {
        _scrollingTime += delta;
        _totalFrames += _framesInLastInterval;
        NSInteger lastFPS = (NSInteger)rintf((CGFloat)_framesInLastInterval / delta);
        CGFloat averageFPS = (CGFloat)(_totalFrames / _scrollingTime);
        [self setAverageFPS:averageFPS];
        
        static dispatch_queue_t __dispatchQueue = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            __dispatchQueue = dispatch_queue_create("com.path.FastImageCacheDemo.ScrollingPerformanceMeasurement", 0);
        });
        
        // We don't want the logging of scrolling performance to be able to impact the scrolling performance,
        // so move both the logging and the string formatting onto a GCD serial queue.
        dispatch_async(__dispatchQueue, ^{
            NSLog(@"*** FIC Demo: Last FPS = %ld, Average FPS = %.2f", (long)lastFPS, averageFPS);
        });
        
        _framesInLastInterval = 0;
        _lastLogTime = currentTime;
    } else {
        _framesInLastInterval++;
    }
}

@end
