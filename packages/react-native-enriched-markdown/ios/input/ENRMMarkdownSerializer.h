#pragma once

#import "ENRMFormattingRange.h"
#import "ENRMImageStore.h"

NS_ASSUME_NONNULL_BEGIN

@interface ENRMMarkdownSerializer : NSObject

+ (NSString *)serializePlainText:(NSString *)text ranges:(NSArray<ENRMFormattingRange *> *)ranges;

+ (NSString *)serializePlainText:(NSString *)text
                          ranges:(NSArray<ENRMFormattingRange *> *)ranges
                    imageEntries:(NSArray<ENRMImageEntry *> *)imageEntries;

@end

NS_ASSUME_NONNULL_END
