#import "ENRMUIKit.h"
#import <React/RCTViewComponentView.h>

#ifndef EnrichedMarkdownTextInput_h
#define EnrichedMarkdownTextInput_h

@class ENRMParseResult;

NS_ASSUME_NONNULL_BEGIN

@interface EnrichedMarkdownTextInput : RCTViewComponentView
@property (nonatomic, assign) BOOL blockEmitting;
- (CGSize)measureSize:(CGFloat)maxWidth;
- (nullable NSString *)markdownForSelectedRange;
- (void)pasteMarkdown:(NSString *)markdown;
- (void)replaceSelectedTextWithParseResult:(ENRMParseResult *)parseResult;
- (void)emitOnPasteImagesEvent:(NSArray<NSDictionary *> *)images;
- (void)scheduleRelayoutIfNeeded;
@end

NS_ASSUME_NONNULL_END

#endif
