#pragma once

#import "ENRMFormattingRange.h"
#import "ENRMInputBlockType.h"
#import "ENRMInputStyledRange.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ENRMParseResult : NSObject
@property (nonatomic, strong, readonly) NSString *plainText;
@property (nonatomic, strong, readonly) NSArray<ENRMFormattingRange *> *formattingRanges;
/// Paragraph block ranges (headings) in `plainText` coordinates.
@property (nonatomic, strong, readonly) NSArray<ENRMBlockRange *> *blockRanges;
@end

@interface ENRMInputParser : NSObject

- (ENRMParseResult *)parseToPlainTextAndRanges:(NSString *)markdown;

@end

NS_ASSUME_NONNULL_END
