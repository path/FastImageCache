//
//  ImageCacheTests.m
//  FastImageCache
//
//  Copyright (c) 2013 Path, Inc.
//  See LICENSE for full license agreement.
//

#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>
#import "FICImageCache.h"
#import "FICImageFormat.h"
#import "TestEntity.h"
#import "TestImageProvider.h"

static NSString *ImageFormatName = @"com.testcompany.testapp.ImageFormatName";

@interface ImageCacheTests : XCTestCase

@property (nonatomic, strong) FICImageCache *imageCache;
@property (nonatomic, strong) TestImageProvider *imageProvider;

@end

@implementation ImageCacheTests

- (void)setUp {
    [super setUp];
    
    self.imageCache = [FICImageCache sharedImageCache];
    
    FICImageFormat *imageFormat = [[FICImageFormat alloc] init];
    imageFormat.name = ImageFormatName;
    imageFormat.style = FICImageFormatStyle16BitBGR;
    imageFormat.devices = FICImageFormatDevicePhone;
    
    [self.imageCache setFormats:@[imageFormat]];
    self.imageProvider = [[TestImageProvider alloc] init];
    self.imageCache.delegate = self.imageProvider;
}

- (void)tearDown {
    [self.imageCache reset];
    [super tearDown];
}

- (void)testSyncronouslyRequestImageNotInCache {
    
    TestEntity *entity = [[TestEntity alloc] init];
    
    NSString *formatName = ImageFormatName;
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"test_success"];
    
    __block BOOL blockCalled = NO;
    
    BOOL imageExists = [self.imageCache retrieveImageForEntity:entity withFormatName:formatName completionBlock:^(id <FICEntity> entity, NSString *formatName, UIImage *image) {
        XCTAssertTrue([NSThread currentThread].isMainThread, @"The completion block should be called on the main thread if the image is not in cach");
        blockCalled = YES;
        [expectation fulfill];
    }];
    
    XCTAssertFalse(blockCalled, @"The block shouldn't have been exectuted since the image is not in cache");
    
    [self waitForExpectationsWithTimeout:5.0f handler:nil];
    
    XCTAssertFalse(imageExists, @"The image should exists");
    XCTAssertTrue(blockCalled, @"The block wasn't executed");
}

- (void)testAsyncronouslyRequestImageNotInCache {
    
    TestEntity *entity = [[TestEntity alloc] init];
    
    NSString *formatName = ImageFormatName;
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"test_success"];
    
    __block BOOL blockCalled = NO;
    
    BOOL imageExists = [self.imageCache asynchronouslyRetrieveImageForEntity:entity withFormatName:formatName completionBlock:^(id <FICEntity> entity, NSString *formatName, UIImage *image) {
        XCTAssertTrue([NSThread currentThread].isMainThread, @"The completion block should be called on the main thread if the image is not in cach");
        blockCalled = YES;
        [expectation fulfill];
    }];
    
    XCTAssertFalse(blockCalled, @"The block shouldn't have been exectuted since the image is not in cache");
    
    [self waitForExpectationsWithTimeout:5.0f handler:nil];
    
    XCTAssertFalse(imageExists, @"The image should exists");
    XCTAssertTrue(blockCalled, @"The block wasn't executed");
}

@end
