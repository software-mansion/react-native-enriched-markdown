#pragma once

#import "ENRMFormattingRange.h"

NS_ASSUME_NONNULL_BEGIN

@interface ENRMMarkdownSerializer : NSObject

+ (NSString *)serializePlainText:(NSString *)text ranges:(NSArray<ENRMFormattingRange *> *)ranges;

@end

NS_ASSUME_NONNULL_END
