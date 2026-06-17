#pragma once
#import "ENRMUIKit.h"

NS_ASSUME_NONNULL_BEGIN

typedef void (^ENRMImageDownloadCompletion)(RCTUIImage *_Nullable image);

@interface ENRMImageDownloader : NSObject

+ (instancetype)shared;

- (void)downloadURL:(NSString *)url completion:(ENRMImageDownloadCompletion)completion;

@end

NS_ASSUME_NONNULL_END
