//
//  AppDelegate.m
//  FastImageCacheOSXDemo
//
//  Created by Xu Lian on 2015-04-16.
//
//

#import "AppDelegate.h"
#import "FICImageCache.h"
#import "FICDPhoto.h"

#define IMAGE_FAMILY_NAME          @"fastimageFamily.v1"
#define IMAGE_SMALL_FORMAT_NAME    @"fastimage_small.v1"
#define IMAGE_SIZE_SMALL           180

static void *ImageDownloaderKVOContext = &ImageDownloaderKVOContext;

@interface AppDelegate ()
{
    NSMutableArray *tableData;
    NSMutableArray *_observedVisibleItems;
}
@property (weak) IBOutlet NSWindow *window;
@end

@implementation AppDelegate

+ (FICImageFormat*)smallImageFormat
{
    FICImageFormat *format = [[FICImageFormat alloc] init];
    format.name = IMAGE_SMALL_FORMAT_NAME;
    format.family = IMAGE_FAMILY_NAME;
    format.style = FICImageFormatStyle32BitBGRA;
    format.imageSize = CGSizeMake(IMAGE_SIZE_SMALL, IMAGE_SIZE_SMALL);
    format.maximumCount = 500;
    return format;
}

- (void)loadTestData
{
    tableData = [[NSMutableArray alloc] init];
    _observedVisibleItems = [NSMutableArray new];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0), ^{
        
        NSString *jsonString = [[NSString alloc] initWithContentsOfURL:[NSURL URLWithString:@"http://lianxu.me/test/photos.json"] encoding:NSUTF8StringEncoding error:nil];
        
        NSError *error = nil;
        NSData *data = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
        NSArray *array = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
  
        for(NSDictionary *d in array){
            NSString *url = d[@"url"];
            url = [url stringByReplacingOccurrencesOfString:@"/50/" withString:@"/180/"];
            FICDPhoto *item=[[FICDPhoto alloc] init];
            item.sourceImageURL = [NSURL URLWithString:url];
            [tableData addObject:item];
        }
        
        __weak __typeof__(self) weakSelf = self;
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            [weakSelf.tableView reloadData];
        }];
        
    });
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Insert code here to initialize your application
    
    FICImageCache *sharedImageCache = [FICImageCache sharedImageCache];
    sharedImageCache.delegate = (id)self;
    sharedImageCache.formats = @[[[self class] smallImageFormat]];
    
    [self loadTestData];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}

#pragma NSTableView Datasource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
    return tableData.count;
}


- (void)tableView:(NSTableView *)tableView didRemoveRowView:(NSTableRowView *)rowView forRow:(NSInteger)row {
    FICDPhoto *item = tableData[row];
    if ([_observedVisibleItems containsObject:item]) {
        @try {
            [item removeObserver:self forKeyPath:@"image"];
        }
        @catch (NSException *exception) {
        }
        @finally {
        }
        [_observedVisibleItems removeObject:item];
    }
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row;
{
    FICDPhoto *item = tableData[row];
    NSTableCellView *cellView = [tableView makeViewWithIdentifier:[tableColumn identifier] owner:self];
    if (cellView) {
        cellView.textField.stringValue = [NSString stringWithFormat:@"row %ld", row];
        cellView.imageView.image = nil;
        [cellView.imageView setHidden:YES];
        
        
        FICImageCache *sharedImageCache = [FICImageCache sharedImageCache];
        
        BOOL imageExists = NO;
        
//        if ([sharedImageCache imageExistsForEntity:item withFormatName:IMAGE_SMALL_FORMAT_NAME]) {
//            imageExists = [sharedImageCache retrieveImageForEntity:item withFormatName:IMAGE_SMALL_FORMAT_NAME completionBlock:^(id <FICEntity> entity, NSString *formatName, NSImage *image) {
//                item.image = image;
//            }];
//        }
        if (!imageExists) {
            [item addObserver:self forKeyPath:@"image" options:0 context:ImageDownloaderKVOContext];
            
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                // Fetch the desired source image by making a network request
                NSImage *sourceImage = [[NSImage alloc] initWithContentsOfURL:item.sourceImageURL];
                dispatch_async(dispatch_get_main_queue(), ^{
                    NSLog(@"sourceImage=%@", sourceImage);
                    [[FICImageCache sharedImageCache] setImage:sourceImage forEntity:item withFormatName:IMAGE_SMALL_FORMAT_NAME completionBlock:^(id <FICEntity> entity, NSString *formatName, NSImage *image) {
                        NSLog(@"cachedImage=%@", image);
                        item.image = image;
                    }];
                });
            });
            
            [_observedVisibleItems addObject:item];
        }
        
    }
    return cellView;
}


#pragma mark - Observer

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    
    if (context == ImageDownloaderKVOContext) {
        
        NSInteger row = [tableData indexOfObject:object];
        if (row != NSNotFound) {
            
            FICDPhoto *item = tableData[row];
            
            NSTableCellView *cellView = [self.tableView viewAtColumn:0 row:row makeIfNecessary:NO];
            if (cellView) {
                [cellView.imageView setImage:item.image];
                [cellView.imageView setNeedsDisplay:YES];
                NSLog(@"cellView.imageView=%@", cellView.imageView);
            }
            else{
                NSLog(@"cellView=nil");
            }
            
            @try {
                [item removeObserver:self forKeyPath:@"image"];
            }
            @catch (NSException *exception) {
            }
            @finally {
            }
        }
    }
}


#pragma mark - FastImageCacheDelegate

- (void)imageCache:(FICImageCache *)imageCache wantsSourceImageForEntity:(id <FICEntity>)entity withFormatName:(NSString *)formatName completionBlock:(FICImageRequestCompletionBlock)completionBlock;
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // Fetch the desired source image by making a network request
        NSURL *requestURL = [entity sourceImageURLWithFormatName:formatName];
        NSImage *sourceImage = [[NSImage alloc] initWithContentsOfURL:requestURL];
        dispatch_async(dispatch_get_main_queue(), ^{
            completionBlock(sourceImage);
        });
    });
}

- (void)imageCache:(FICImageCache *)imageCache cancelImageLoadingForEntity:(id <FICEntity>)entity withFormatName:(NSString *)formatName;
{
    NSLog(@"imageCache cancelImageLoadingForEntity %@", entity);
}

- (void)imageCache:(FICImageCache *)imageCache errorDidOccurWithMessage:(NSString *)errorMessage;
{
    NSLog(@"imageCache errorDidOccurWithMessage %@", errorMessage);
}


@end
