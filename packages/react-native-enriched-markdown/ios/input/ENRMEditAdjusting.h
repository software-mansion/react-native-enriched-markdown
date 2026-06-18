#pragma once
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol ENRMEditAdjusting <NSObject>

- (void)adjustForEditAtLocation:(NSUInteger)location
                  deletedLength:(NSUInteger)deletedLength
                 insertedLength:(NSUInteger)insertedLength;
- (void)clearAll;

@end

NS_ASSUME_NONNULL_END
