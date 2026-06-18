#pragma once

#import "ENRMEditAdjusting.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ENRMImageEntry : NSObject

@property (nonatomic, assign) NSUInteger position;
@property (nonatomic, copy) NSString *url;
@property (nonatomic, copy) NSString *alt;
@property (nonatomic, assign) CGFloat width;
@property (nonatomic, assign) CGFloat height;
@property (nonatomic, assign) BOOL isInline;

+ (instancetype)entryWithPosition:(NSUInteger)position
                              url:(NSString *)url
                              alt:(NSString *)alt
                            width:(CGFloat)width
                           height:(CGFloat)height
                         isInline:(BOOL)isInline;

@end

@interface ENRMImageStore : NSObject <ENRMEditAdjusting>

@property (nonatomic, readonly) NSArray<ENRMImageEntry *> *allEntries;

- (void)addEntry:(ENRMImageEntry *)entry;
- (void)removeEntryAtPosition:(NSUInteger)position;
- (nullable ENRMImageEntry *)entryAtPosition:(NSUInteger)position;
- (void)clearAll;

- (void)adjustForEditAtLocation:(NSUInteger)editLocation
                  deletedLength:(NSUInteger)deletedLength
                 insertedLength:(NSUInteger)insertedLength;

@end

NS_ASSUME_NONNULL_END
