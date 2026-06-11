#import "ENRMUIKit.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

__BEGIN_DECLS

extern NSAttributedString *kNewlineAttributedString;

NSWritingDirection currentWritingDirection(void);
NSMutableParagraphStyle *getOrCreateParagraphStyle(NSMutableAttributedString *output, NSUInteger index);
void applyParagraphSpacingAfter(NSMutableAttributedString *output, NSUInteger start, CGFloat marginBottom);
NSUInteger applyParagraphSpacingBefore(NSMutableAttributedString *output, NSRange range, CGFloat marginTop);
NSUInteger applyBlockSpacingBefore(NSMutableAttributedString *output, NSUInteger insertionPoint, CGFloat marginTop);
void applyBlockSpacingAfter(NSMutableAttributedString *output, CGFloat marginBottom);
void applyLineHeight(NSMutableAttributedString *output, NSRange range, CGFloat lineHeight);
void applyBaselineOffset(NSMutableAttributedString *output, NSRange range);
void applyTextAlignment(NSMutableAttributedString *output, NSRange range, NSTextAlignment textAlign);
NSTextAlignment textAlignmentFromString(NSString *textAlign);

__END_DECLS

NS_ASSUME_NONNULL_END
