#import "ENRMImageDownloader.h"
#import "ENRMImageAttachment.h"
#include <TargetConditionals.h>

static const NSUInteger kDiskCacheMemoryCapacity = 10 * 1024 * 1024;
static const NSUInteger kDiskCacheDiskCapacity = 100 * 1024 * 1024;

static inline NSUInteger ENRMImageByteCost(RCTUIImage *image)
{
  CGImageRef cgImage = image.CGImage;
  if (!cgImage)
    return 0;
  return CGImageGetBytesPerRow(cgImage) * CGImageGetHeight(cgImage);
}

@implementation ENRMImageDownloader {
  NSURLSession *_session;
  NSMutableDictionary<NSString *, NSMutableArray<ENRMImageDownloadCompletion> *> *_inFlightRequests;
}

+ (instancetype)shared
{
  static ENRMImageDownloader *instance;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{ instance = [[ENRMImageDownloader alloc] init]; });
  return instance;
}

- (instancetype)init
{
  self = [super init];
  if (self) {
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    config.URLCache = [[NSURLCache alloc] initWithMemoryCapacity:kDiskCacheMemoryCapacity
                                                    diskCapacity:kDiskCacheDiskCapacity
                                                    directoryURL:nil];
    config.requestCachePolicy = NSURLRequestReturnCacheDataElseLoad;
    config.timeoutIntervalForRequest = 15;
    config.timeoutIntervalForResource = 30;
    _session = [NSURLSession sessionWithConfiguration:config];
    _inFlightRequests = [NSMutableDictionary dictionary];
  }
  return self;
}

- (void)downloadURL:(NSString *)url completion:(ENRMImageDownloadCompletion)completion
{
  if (url.length == 0) {
    completion(nil);
    return;
  }

  RCTUIImage *cached = [[ENRMImageAttachment originalImageCache] objectForKey:url];
  if (cached) {
    completion(cached);
    return;
  }

  @synchronized(_inFlightRequests) {
    NSMutableArray *existing = _inFlightRequests[url];
    if (existing) {
      [existing addObject:completion];
      return;
    }
    _inFlightRequests[url] = [NSMutableArray arrayWithObject:completion];
  }

  NSURL *nsURL = [NSURL URLWithString:url];
  if (!nsURL) {
    [self dispatchCallbacksForURL:url image:nil];
    return;
  }

  [[_session dataTaskWithURL:nsURL
           completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
#if !TARGET_OS_OSX
             RCTUIImage *image = (data && !error) ? [RCTUIImage imageWithData:data] : nil;
#else
        RCTUIImage *image = (data && !error) ? [[RCTUIImage alloc] initWithData:data] : nil;
#endif

             if (image) {
               [[ENRMImageAttachment originalImageCache] setObject:image forKey:url cost:ENRMImageByteCost(image)];
             }

             [self dispatchCallbacksForURL:url image:image];
           }] resume];
}

- (void)dispatchCallbacksForURL:(NSString *)url image:(RCTUIImage *_Nullable)image
{
  NSArray<ENRMImageDownloadCompletion> *callbacks;
  @synchronized(_inFlightRequests) {
    callbacks = [_inFlightRequests[url] copy];
    [_inFlightRequests removeObjectForKey:url];
  }

  if (!callbacks)
    return;

  dispatch_async(dispatch_get_main_queue(), ^{
    for (ENRMImageDownloadCompletion cb in callbacks) {
      cb(image);
    }
  });
}

@end
