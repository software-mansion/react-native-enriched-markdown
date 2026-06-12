#import "ENRMUIKit.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

__BEGIN_DECLS

extern NSAttributedString *kNewlineAttributedString;

NSWritingDirection currentWritingDirection(void);
NSLineBreakStrategy ENRMResolveLineBreakStrategy(NSString *_Nullable strategy);

NSMutableParagraphStyle *getOrCreateParagraphStyle(NSMutableAttributedString *output, NSUInteger index,
                                                   NSLineBreakStrategy lineBreakStrategy);
void applyParagraphSpacingAfter(NSMutableAttributedString *output, NSUInteger start, CGFloat marginBottom,
                                NSLineBreakStrategy lineBreakStrategy);
NSUInteger applyParagraphSpacingBefore(NSMutableAttributedString *output, NSRange range, CGFloat marginTop);
NSUInteger applyBlockSpacingBefore(NSMutableAttributedString *output, NSUInteger insertionPoint, CGFloat marginTop);
void applyBlockSpacingAfter(NSMutableAttributedString *output, CGFloat marginBottom);
void applyLineHeight(NSMutableAttributedString *output, NSRange range, CGFloat lineHeight,
                     NSLineBreakStrategy lineBreakStrategy);
void applyTextAlignment(NSMutableAttributedString *output, NSRange range, NSTextAlignment textAlign,
                        NSLineBreakStrategy lineBreakStrategy);
NSTextAlignment textAlignmentFromString(NSString *textAlign);
void ENRMSetLineBreakStrategy(NSString *strategy);

__END_DECLS

NS_ASSUME_NONNULL_END
