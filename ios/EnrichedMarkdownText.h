#import "ENRMUIKit.h"
#import "StyleConfig.h"
#import <React/RCTViewComponentView.h>

#ifndef EnrichedMarkdownTextNativeComponent_h
#define EnrichedMarkdownTextNativeComponent_h

NS_ASSUME_NONNULL_BEGIN

@interface EnrichedMarkdownText : RCTViewComponentView
@property (nonatomic, strong) StyleConfig *config;
- (CGSize)measureSize:(CGFloat)maxWidth;
- (void)renderMarkdownSynchronously:(NSString *)markdownString;
- (BOOL)hasRenderedMarkdown:(NSString *)markdown;
- (BOOL)hasRenderedWithStyleFingerprint:(size_t)fingerprint;
@end

NS_ASSUME_NONNULL_END

#endif
