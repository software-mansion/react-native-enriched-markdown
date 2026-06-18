#pragma once
#import "ENRMFormattingRange.h"
#import "ENRMImageStore.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ENRMParseResult : NSObject
@property (nonatomic, strong, readonly) NSString *plainText;
@property (nonatomic, strong, readonly) NSArray<ENRMFormattingRange *> *formattingRanges;
@property (nonatomic, strong, readonly) NSArray<ENRMImageEntry *> *imageEntries;

+ (instancetype)resultWithPlainText:(NSString *)plainText
                   formattingRanges:(NSArray<ENRMFormattingRange *> *)formattingRanges
                       imageEntries:(NSArray<ENRMImageEntry *> *)imageEntries;
@end

NS_ASSUME_NONNULL_END
