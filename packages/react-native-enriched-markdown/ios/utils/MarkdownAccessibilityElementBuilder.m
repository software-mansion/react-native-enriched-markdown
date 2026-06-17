#import "MarkdownAccessibilityElementBuilder.h"
#import "AccessibilityInfo.h"
#include <TargetConditionals.h>

typedef NS_ENUM(NSInteger, ElementType) { ElementTypeText, ElementTypeLink, ElementTypeImage };

static const CGFloat kFocusRectPadding = 2.0;

@implementation MarkdownAccessibilityElementBuilder

#if !TARGET_OS_OSX

#pragma mark - Public API

+ (NSMutableArray<UIAccessibilityElement *> *)buildElementsForTextView:(UITextView *)textView
                                                                  info:(AccessibilityInfo *)info
                                                             container:(id)container
{
  NSString *fullString = textView.attributedText.string;
  if (fullString.length == 0)
    return [NSMutableArray array];

  [textView.layoutManager ensureLayoutForTextContainer:textView.textContainer];

  NSMutableArray<UIAccessibilityElement *> *elements = [NSMutableArray array];
  NSUInteger currentPos = 0;

  while (currentPos < fullString.length) {
    NSRange paragraphRange = [fullString paragraphRangeForRange:NSMakeRange(currentPos, 0)];
    NSString *trimmed = [[fullString substringWithRange:paragraphRange]
        stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

    if (trimmed.length > 0) {
      NSArray *links = [self linksInRange:paragraphRange info:info];
      NSArray *images = [self imagesInRange:paragraphRange info:info];
      NSArray *specials = [links arrayByAddingObjectsFromArray:images];

      NSInteger level = [self headingLevelForRange:paragraphRange info:info];
      NSDictionary *list = [self listItemInfoForRange:paragraphRange info:info];

      if (specials.count == 0) {
        [elements addObject:[self createElementForRange:paragraphRange
                                                   type:ElementTypeText
                                                   text:trimmed
                                               isLinked:NO
                                                heading:level
                                               listInfo:list
                                                   view:textView
                                              container:container]];
      } else {
        [elements addObjectsFromArray:[self segmentedElementsForParagraph:paragraphRange
                                                                 fullText:fullString
                                                             headingLevel:level
                                                                 listInfo:list
                                                                 specials:specials
                                                               inTextView:textView
                                                                container:container]];
      }
    }
    currentPos = NSMaxRange(paragraphRange);
  }
  return elements;
}

#pragma mark - Segmentation

+ (BOOL)hasAlphanumericContent:(NSString *)text
{
  static NSCharacterSet *alphanumericSet;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{ alphanumericSet = [NSCharacterSet alphanumericCharacterSet]; });
  return [text rangeOfCharacterFromSet:alphanumericSet].location != NSNotFound;
}

+ (NSArray<UIAccessibilityElement *> *)segmentedElementsForParagraph:(NSRange)paragraphRange
                                                            fullText:(NSString *)fullText
                                                        headingLevel:(NSInteger)headingLevel
                                                            listInfo:(NSDictionary *)listInfo
                                                            specials:(NSArray *)specials
                                                          inTextView:(UITextView *)textView
                                                           container:(id)container
{
  NSMutableArray<UIAccessibilityElement *> *elements = [NSMutableArray array];
  NSArray *sortedSpecials = [specials sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
    return [@([a[@"range"] rangeValue].location) compare:@([b[@"range"] rangeValue].location)];
  }];

  NSUInteger segmentStart = paragraphRange.location;
  for (NSDictionary *item in sortedSpecials) {
    NSRange itemRange = [item[@"range"] rangeValue];

    if (itemRange.location > segmentStart) {
      NSRange beforeRange = NSMakeRange(segmentStart, itemRange.location - segmentStart);
      NSString *beforeText = [[fullText substringWithRange:beforeRange]
          stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
      if (beforeText.length > 0 && [self hasAlphanumericContent:beforeText]) {
        [elements addObject:[self createElementForRange:beforeRange
                                                   type:ElementTypeText
                                                   text:beforeText
                                               isLinked:NO
                                                heading:headingLevel
                                               listInfo:listInfo
                                                   view:textView
                                              container:container]];
      }
    }

    BOOL isImg = item[@"altText"] != nil;
    NSString *label = isImg ? item[@"altText"] : [fullText substringWithRange:itemRange];
    [elements addObject:[self createElementForRange:itemRange
                                               type:isImg ? ElementTypeImage : ElementTypeLink
                                               text:label
                                           isLinked:isImg ? [item[@"isLinked"] boolValue] : YES
                                            heading:0
                                           listInfo:listInfo
                                               view:textView
                                          container:container]];
    segmentStart = NSMaxRange(itemRange);
  }

  if (segmentStart < NSMaxRange(paragraphRange)) {
    NSRange afterRange = NSMakeRange(segmentStart, NSMaxRange(paragraphRange) - segmentStart);
    NSString *afterText = [[fullText substringWithRange:afterRange]
        stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (afterText.length > 0 && [self hasAlphanumericContent:afterText]) {
      [elements addObject:[self createElementForRange:afterRange
                                                 type:ElementTypeText
                                                 text:afterText
                                             isLinked:NO
                                              heading:headingLevel
                                             listInfo:listInfo
                                                 view:textView
                                            container:container]];
    }
  }
  return elements;
}

#pragma mark - Factory

+ (UIAccessibilityElement *)createElementForRange:(NSRange)range
                                             type:(ElementType)type
                                             text:(NSString *)text
                                         isLinked:(BOOL)linked
                                          heading:(NSInteger)level
                                         listInfo:(NSDictionary *)listInfo
                                             view:(UITextView *)textView
                                        container:(id)container
{
  UIAccessibilityElement *element = [[UIAccessibilityElement alloc] initWithAccessibilityContainer:container];
  element.accessibilityLabel = (type == ElementTypeImage && text.length == 0) ? NSLocalizedString(@"Image", @"") : text;

  UIBezierPath *path = [self accessibilityPathForRange:range inTextView:textView];
  if (path) {
    element.accessibilityPath = path;
  } else {
    element.accessibilityFrameInContainerSpace = [self frameForRange:range inTextView:textView container:container];
  }

  NSMutableArray *values = [NSMutableArray array];

  if (type == ElementTypeImage) {
    element.accessibilityTraits =
        linked ? (UIAccessibilityTraitImage | UIAccessibilityTraitLink) : UIAccessibilityTraitImage;
  } else if (type == ElementTypeLink) {
    element.accessibilityTraits = UIAccessibilityTraitLink;
  } else if (level > 0) {
    element.accessibilityTraits = UIAccessibilityTraitHeader;
    [values addObject:[NSString stringWithFormat:NSLocalizedString(@"heading level %ld", @""), (long)level]];
  }

  if (element.accessibilityTraits & UIAccessibilityTraitLink) {
    element.accessibilityHint = NSLocalizedString(@"Tap to open link", @"");
  }

  if (listInfo && type != ElementTypeImage) {
    [values addObject:[self formatListAnnouncement:listInfo]];
  }

  if (values.count > 0) {
    element.accessibilityValue = [values componentsJoinedByString:@", "];
  }

  return element;
}

#pragma mark - Helpers

+ (NSString *)formatListAnnouncement:(NSDictionary *)info
{
  NSString *prefix = [info[@"depth"] integerValue] > 1 ? @"nested " : @"";
  return [info[@"isOrdered"] boolValue]
             ? [NSString stringWithFormat:@"%@list item %ld", prefix, (long)[info[@"position"] integerValue]]
             : [NSString stringWithFormat:@"%@bullet point", prefix];
}

+ (NSRange)clampedRange:(NSRange)range forText:(NSString *)text
{
  if (text.length == 0 || range.location >= text.length)
    return NSMakeRange(NSNotFound, 0);
  return NSMakeRange(range.location, MIN(range.length, text.length - range.location));
}

+ (NSArray<NSValue *> *)perLineRectsForGlyphRange:(NSRange)glyphRange inTextView:(UITextView *)textView
{
  NSLayoutManager *layoutManager = textView.layoutManager;
  UIEdgeInsets insets = textView.textContainerInset;
  NSMutableArray<NSValue *> *rects = [NSMutableArray array];

  [layoutManager
      enumerateLineFragmentsForGlyphRange:glyphRange
                               usingBlock:^(CGRect lineRect, CGRect usedRect, NSTextContainer *textContainer,
                                            NSRange lineGlyphRange, BOOL *stop) {
                                 NSRange overlap = NSIntersectionRange(glyphRange, lineGlyphRange);
                                 if (overlap.length == 0)
                                   return;

                                 CGFloat left = [layoutManager locationForGlyphAtIndex:overlap.location].x;
                                 BOOL extendsToLineEnd = (NSMaxRange(overlap) == NSMaxRange(lineGlyphRange));
                                 CGFloat right = extendsToLineEnd
                                                     ? CGRectGetMaxX(usedRect)
                                                     : [layoutManager locationForGlyphAtIndex:NSMaxRange(overlap)].x;

                                 CGRect rect =
                                     CGRectMake(left, CGRectGetMinY(usedRect), right - left, CGRectGetHeight(usedRect));
                                 rect = CGRectInset(rect, -kFocusRectPadding, -kFocusRectPadding);
                                 rect = CGRectOffset(rect, insets.left, insets.top);
                                 [rects addObject:[NSValue valueWithCGRect:rect]];
                               }];

  return rects;
}

+ (UIBezierPath *)accessibilityPathForRange:(NSRange)range inTextView:(UITextView *)textView
{
  NSRange clamped = [self clampedRange:range forText:textView.attributedText.string];
  if (clamped.location == NSNotFound)
    return nil;

  NSRange glyphRange = [textView.layoutManager glyphRangeForCharacterRange:clamped actualCharacterRange:NULL];
  NSArray<NSValue *> *lineRects = [self perLineRectsForGlyphRange:glyphRange inTextView:textView];
  if (lineRects.count <= 1)
    return nil;

  UIWindow *window = textView.window;
  if (!window)
    return nil;

  id<UICoordinateSpace> screenSpace = window.screen.coordinateSpace;
  UIBezierPath *path = [UIBezierPath bezierPath];
  for (NSValue *value in lineRects) {
    CGRect screenRect = [textView convertRect:CGRectIntegral(value.CGRectValue) toCoordinateSpace:screenSpace];
    [path appendPath:[UIBezierPath bezierPathWithRect:screenRect]];
  }
  return path;
}

+ (CGRect)frameForRange:(NSRange)range inTextView:(UITextView *)textView container:(id)container
{
  NSRange clamped = [self clampedRange:range forText:textView.attributedText.string];
  if (clamped.location == NSNotFound)
    return CGRectZero;

  NSRange glyphRange = [textView.layoutManager glyphRangeForCharacterRange:clamped actualCharacterRange:NULL];
  CGRect rect = [textView.layoutManager boundingRectForGlyphRange:glyphRange inTextContainer:textView.textContainer];
  rect = CGRectInset(rect, -kFocusRectPadding, -kFocusRectPadding);
  rect = CGRectOffset(rect, textView.textContainerInset.left, textView.textContainerInset.top);
  return [(UIView *)container convertRect:CGRectIntegral(rect) fromView:textView];
}

#pragma mark - Data Helpers

+ (NSInteger)headingLevelForRange:(NSRange)range info:(AccessibilityInfo *)info
{
  for (NSUInteger i = 0; i < info.headingRanges.count; i++) {
    if (NSIntersectionRange(range, [info.headingRanges[i] rangeValue]).length > 0)
      return [info.headingLevels[i] integerValue];
  }
  return 0;
}

+ (NSArray *)linksInRange:(NSRange)range info:(AccessibilityInfo *)info
{
  NSMutableArray *links = [NSMutableArray array];
  for (NSUInteger i = 0; i < info.linkRanges.count; i++) {
    if (NSIntersectionRange(range, [info.linkRanges[i] rangeValue]).length > 0) {
      [links addObject:@{@"range" : info.linkRanges[i], @"url" : info.linkURLs[i] ?: @""}];
    }
  }
  return links;
}

+ (NSArray *)imagesInRange:(NSRange)range info:(AccessibilityInfo *)info
{
  NSMutableArray *images = [NSMutableArray array];
  for (NSUInteger i = 0; i < info.imageRanges.count; i++) {
    NSRange imgRange = [info.imageRanges[i] rangeValue];
    if (NSIntersectionRange(range, imgRange).length > 0) {
      BOOL linked = NO;
      for (NSValue *linkRange in info.linkRanges)
        if (NSIntersectionRange(imgRange, linkRange.rangeValue).length > 0) {
          linked = YES;
          break;
        }
      [images addObject:@{
        @"range" : info.imageRanges[i],
        @"altText" : info.imageAltTexts[i] ?: @"",
        @"isLinked" : @(linked)
      }];
    }
  }
  return images;
}

+ (NSDictionary *)listItemInfoForRange:(NSRange)range info:(AccessibilityInfo *)info
{
  if (!info)
    return nil;
  for (NSUInteger i = 0; i < info.listItemRanges.count; i++) {
    if (NSIntersectionRange(range, [info.listItemRanges[i] rangeValue]).length > 0) {
      return @{
        @"position" : info.listItemPositions[i],
        @"depth" : info.listItemDepths[i],
        @"isOrdered" : info.listItemOrdered[i]
      };
    }
  }
  return nil;
}

#pragma mark - Rotors

+ (NSArray *)filterElements:(NSArray *)elements withTrait:(UIAccessibilityTraits)trait
{
  return [elements
      filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(UIAccessibilityElement *element, id bindings) {
        return (element.accessibilityTraits & trait) != 0;
      }]];
}

+ (UIAccessibilityCustomRotor *)createRotorWithName:(NSString *)name elements:(NSArray *)elements
{
  return [[UIAccessibilityCustomRotor alloc]
         initWithName:name
      itemSearchBlock:^UIAccessibilityCustomRotorItemResult *(UIAccessibilityCustomRotorSearchPredicate *predicate) {
        if (elements.count == 0)
          return nil;
        NSInteger currentIndex = predicate.currentItem.targetElement
                                     ? [elements indexOfObject:predicate.currentItem.targetElement]
                                     : NSNotFound;
        NSInteger nextIndex = (predicate.searchDirection == UIAccessibilityCustomRotorDirectionNext)
                                  ? (currentIndex == NSNotFound ? 0 : currentIndex + 1)
                                  : (currentIndex == NSNotFound ? (NSInteger)elements.count - 1 : currentIndex - 1);
        return (nextIndex >= 0 && nextIndex < (NSInteger)elements.count)
                   ? [[UIAccessibilityCustomRotorItemResult alloc] initWithTargetElement:elements[nextIndex]
                                                                             targetRange:nil]
                   : nil;
      }];
}

+ (NSArray<UIAccessibilityElement *> *)filterHeadingElements:(NSArray *)elements
{
  return [self filterElements:elements withTrait:UIAccessibilityTraitHeader];
}
+ (NSArray<UIAccessibilityElement *> *)filterLinkElements:(NSArray *)elements
{
  return [self filterElements:elements withTrait:UIAccessibilityTraitLink];
}
+ (NSArray<UIAccessibilityElement *> *)filterImageElements:(NSArray *)elements
{
  return [self filterElements:elements withTrait:UIAccessibilityTraitImage];
}
+ (UIAccessibilityCustomRotor *)createHeadingRotorWithElements:(NSArray *)elements
{
  return [self createRotorWithName:NSLocalizedString(@"Headings", @"") elements:elements];
}
+ (UIAccessibilityCustomRotor *)createLinkRotorWithElements:(NSArray *)elements
{
  return [self createRotorWithName:NSLocalizedString(@"Links", @"") elements:elements];
}
+ (UIAccessibilityCustomRotor *)createImageRotorWithElements:(NSArray *)elements
{
  return [self createRotorWithName:NSLocalizedString(@"Images", @"") elements:elements];
}

+ (NSArray<UIAccessibilityCustomRotor *> *)buildRotorsFromElements:(NSArray<UIAccessibilityElement *> *)elements
{
  NSMutableArray<UIAccessibilityCustomRotor *> *rotors = [NSMutableArray array];

  NSArray<UIAccessibilityElement *> *headingElements = [self filterHeadingElements:elements];
  if (headingElements.count > 0) {
    [rotors addObject:[self createHeadingRotorWithElements:headingElements]];
  }

  NSArray<UIAccessibilityElement *> *linkElements = [self filterLinkElements:elements];
  if (linkElements.count > 0) {
    [rotors addObject:[self createLinkRotorWithElements:linkElements]];
  }

  NSArray<UIAccessibilityElement *> *imageElements = [self filterImageElements:elements];
  if (imageElements.count > 0) {
    [rotors addObject:[self createImageRotorWithElements:imageElements]];
  }

  return rotors;
}

#else

// TODO: Implement VoiceOver accessibility elements for macOS using NSAccessibility.
// This includes building heading, link, and image accessibility elements from AttributedString
// attributes, and exposing them via NSAccessibilityElement so VoiceOver can navigate the
// rendered markdown content. The iOS implementation above can serve as a reference.

+ (NSMutableArray *)buildElementsForTextView:(id)textView info:(AccessibilityInfo *)info container:(id)container
{
  return [NSMutableArray array];
}
+ (NSArray *)filterHeadingElements:(NSArray *)elements
{
  return @[];
}
+ (NSArray *)filterLinkElements:(NSArray *)elements
{
  return @[];
}
+ (NSArray *)filterImageElements:(NSArray *)elements
{
  return @[];
}
+ (id)createHeadingRotorWithElements:(NSArray *)elements
{
  return nil;
}
+ (id)createLinkRotorWithElements:(NSArray *)elements
{
  return nil;
}
+ (id)createImageRotorWithElements:(NSArray *)elements
{
  return nil;
}
+ (NSArray *)buildRotorsFromElements:(NSArray *)elements
{
  return @[];
}

#endif

@end