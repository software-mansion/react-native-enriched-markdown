#pragma once

#import "ENRMInputStyledRange.h"
#import "ENRMParseResult.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ENRMInputParser : NSObject

- (ENRMParseResult *)parseToPlainTextAndRanges:(NSString *)markdown;

@end

NS_ASSUME_NONNULL_END
