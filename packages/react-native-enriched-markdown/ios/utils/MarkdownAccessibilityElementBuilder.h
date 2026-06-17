#import "ENRMUIKit.h"
#include <TargetConditionals.h>

@class AccessibilityInfo;

NS_ASSUME_NONNULL_BEGIN

/**
 * Builds accessibility elements from markdown content for assistive technologies.
 * On iOS this provides VoiceOver support; on macOS this is a no-op stub pending full NSAccessibility implementation.
 */
@interface MarkdownAccessibilityElementBuilder : NSObject

#if !TARGET_OS_OSX
/**
 * Builds UIAccessibilityElement objects from markdown content for VoiceOver.
 */
+ (NSMutableArray<UIAccessibilityElement *> *)buildElementsForTextView:(UITextView *)textView
                                                                  info:(AccessibilityInfo *)info
                                                             container:(id)container;
+ (NSArray<UIAccessibilityElement *> *)filterHeadingElements:(NSArray<UIAccessibilityElement *> *)elements;
+ (NSArray<UIAccessibilityElement *> *)filterLinkElements:(NSArray<UIAccessibilityElement *> *)elements;
+ (NSArray<UIAccessibilityElement *> *)filterImageElements:(NSArray<UIAccessibilityElement *> *)elements;
+ (UIAccessibilityCustomRotor *)createHeadingRotorWithElements:(NSArray<UIAccessibilityElement *> *)elements;
+ (UIAccessibilityCustomRotor *)createLinkRotorWithElements:(NSArray<UIAccessibilityElement *> *)elements;
+ (UIAccessibilityCustomRotor *)createImageRotorWithElements:(NSArray<UIAccessibilityElement *> *)elements;
+ (NSArray<UIAccessibilityCustomRotor *> *)buildRotorsFromElements:(NSArray<UIAccessibilityElement *> *)elements;
#else
+ (NSMutableArray *)buildElementsForTextView:(id)textView info:(AccessibilityInfo *)info container:(id)container;
+ (NSArray *)filterHeadingElements:(NSArray *)elements;
+ (NSArray *)filterLinkElements:(NSArray *)elements;
+ (NSArray *)filterImageElements:(NSArray *)elements;
+ (id _Nullable)createHeadingRotorWithElements:(NSArray *)elements;
+ (id _Nullable)createLinkRotorWithElements:(NSArray *)elements;
+ (id _Nullable)createImageRotorWithElements:(NSArray *)elements;
+ (NSArray *)buildRotorsFromElements:(NSArray *)elements;
#endif

@end

NS_ASSUME_NONNULL_END
