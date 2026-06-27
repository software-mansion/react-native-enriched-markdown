#pragma once

#import "ENRMFormattingRange.h"
#import "ENRMInputBlockType.h"

NS_ASSUME_NONNULL_BEGIN

@interface ENRMMarkdownSerializer : NSObject

+ (NSString *)serializePlainText:(NSString *)text ranges:(NSArray<ENRMFormattingRange *> *)ranges;

/// Serializes inline marks (via the method above) and then prefixes each line
/// with its block marker (`# `/`## `/`### ` for headings). Block markers are
/// line-based, so this runs after inline serialization, which preserves the
/// text's line structure.
+ (NSString *)serializePlainText:(NSString *)text
                          ranges:(NSArray<ENRMFormattingRange *> *)ranges
                     blockRanges:(NSArray<ENRMBlockRange *> *)blockRanges;

@end

NS_ASSUME_NONNULL_END
