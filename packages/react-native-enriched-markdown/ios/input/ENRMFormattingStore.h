#pragma once

#import "ENRMFormattingRange.h"

NS_ASSUME_NONNULL_BEGIN

@interface ENRMFormattingStore : NSObject

@property (nonatomic, readonly) NSArray<ENRMFormattingRange *> *allRanges;

- (void)setRanges:(NSArray<ENRMFormattingRange *> *)ranges;
- (void)clearAll;

- (nullable ENRMFormattingRange *)rangeOfType:(ENRMInputStyleType)type containingPosition:(NSUInteger)position;
- (BOOL)isStyleActive:(ENRMInputStyleType)type atPosition:(NSUInteger)position;
- (BOOL)isStyleActive:(ENRMInputStyleType)type inRange:(NSRange)range;
- (NSArray<ENRMFormattingRange *> *)rangesOfType:(ENRMInputStyleType)type;

- (void)addRange:(ENRMFormattingRange *)range;
- (void)removeType:(ENRMInputStyleType)type inRange:(NSRange)range;
- (void)removeRange:(ENRMFormattingRange *)range;

- (void)adjustForEditAtLocation:(NSUInteger)location
                  deletedLength:(NSUInteger)deletedLength
                 insertedLength:(NSUInteger)insertedLength;

@end

NS_ASSUME_NONNULL_END
