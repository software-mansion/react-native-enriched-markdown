#import "ENRMInputFormatter.h"
#import "ENRMBoldStyleHandler.h"
#import "ENRMInputBlockType.h"
#import "ENRMItalicStyleHandler.h"
#import "ENRMLinkStyleHandler.h"
#import "ENRMSpoilerStyleHandler.h"
#import "ENRMStrikethroughStyleHandler.h"
#import "ENRMStyleHandler.h"
#import "ENRMUnderlineStyleHandler.h"

@implementation ENRMInputLinkVariantStyle
@end

@implementation ENRMInputFormatterStyle {
  NSMutableDictionary<NSNumber *, UIFont *> *_fontCache;
  UIFont *_lastBaseFont;
}

- (instancetype)init
{
  if (self = [super init]) {
    _baseFont = [UIFont systemFontOfSize:16.0];
    _baseTextColor = [RCTUIColor labelColor];
    _linkVariants = @[];
    _fontCache = [NSMutableDictionary dictionary];
  }
  return self;
}

- (id)copyWithZone:(NSZone *)zone
{
  ENRMInputFormatterStyle *copy = [[ENRMInputFormatterStyle allocWithZone:zone] init];
  copy.baseFont = _baseFont;
  copy.baseTextColor = _baseTextColor;
  copy.boldColor = _boldColor;
  copy.italicColor = _italicColor;
  copy.linkColor = _linkColor;
  copy.linkUnderline = _linkUnderline;
  copy.linkBackgroundColor = _linkBackgroundColor;
  copy.linkVariants = [_linkVariants copy];
  copy.spoilerColor = _spoilerColor;
  copy.spoilerBackgroundColor = _spoilerBackgroundColor;
  return copy;
}

- (void)invalidateCacheIfNeeded
{
  if (_lastBaseFont != _baseFont) {
    [_fontCache removeAllObjects];
    _lastBaseFont = _baseFont;
  }
}

- (void)invalidateFontCache
{
  [_fontCache removeAllObjects];
  _lastBaseFont = nil;
}

- (UIFont *)fontForTraits:(UIFontDescriptorSymbolicTraits)traits
{
  [self invalidateCacheIfNeeded];

  if (traits == 0) {
    return _baseFont;
  }

  NSNumber *key = @(traits);
  UIFont *cached = _fontCache[key];
  if (cached) {
    return cached;
  }

  UIFontDescriptor *descriptor =
      [_baseFont.fontDescriptor fontDescriptorWithSymbolicTraits:_baseFont.fontDescriptor.symbolicTraits | traits];
  UIFont *derived = descriptor ? [UIFont fontWithDescriptor:descriptor size:0] : _baseFont;
  _fontCache[key] = derived;
  return derived;
}

@end

@implementation ENRMInputFormatter {
  NSDictionary<NSNumber *, id<ENRMStyleHandler>> *_styleHandlers;
}

- (instancetype)init
{
  if (self = [super init]) {
    NSArray<id<ENRMStyleHandler>> *handlers = @[
      [[ENRMBoldStyleHandler alloc] init],
      [[ENRMItalicStyleHandler alloc] init],
      [[ENRMUnderlineStyleHandler alloc] init],
      [[ENRMStrikethroughStyleHandler alloc] init],
      [[ENRMLinkStyleHandler alloc] init],
      [[ENRMSpoilerStyleHandler alloc] init],
    ];
    NSMutableDictionary<NSNumber *, id<ENRMStyleHandler>> *map = [NSMutableDictionary dictionary];
    for (id<ENRMStyleHandler> handler in handlers) {
      map[@(handler.styleType)] = handler;
    }
    _styleHandlers = [map copy];
  }
  return self;
}

- (nullable id<ENRMStyleHandler>)handlerForStyleType:(ENRMInputStyleType)type
{
  return _styleHandlers[@(type)];
}

- (void)applyFormattingRanges:(NSArray<ENRMFormattingRange *> *)ranges
                   toTextView:(ENRMPlatformTextView *)textView
                        style:(ENRMInputFormatterStyle *)style
{
  NSTextStorage *textStorage = textView.textStorage;
  NSUInteger textLength = textStorage.length;

  if (textLength == 0) {
    return;
  }

  NSRange fullTextRange = NSMakeRange(0, textLength);

  [textStorage beginEditing];

  [textStorage addAttribute:NSFontAttributeName value:style.baseFont range:fullTextRange];
  [textStorage addAttribute:NSForegroundColorAttributeName value:style.baseTextColor range:fullTextRange];
  [textStorage removeAttribute:NSUnderlineStyleAttributeName range:fullTextRange];
  [textStorage removeAttribute:NSStrikethroughStyleAttributeName range:fullTextRange];
  [textStorage removeAttribute:NSBackgroundColorAttributeName range:fullTextRange];
  [textStorage removeAttribute:NSParagraphStyleAttributeName range:fullTextRange];

  UIFontDescriptorSymbolicTraits *traitMap =
      (UIFontDescriptorSymbolicTraits *)calloc(textLength, sizeof(UIFontDescriptorSymbolicTraits));
  if (!traitMap) {
    [textStorage endEditing];
    return;
  }

  for (ENRMFormattingRange *formattingRange in ranges) {
    if (formattingRange.range.length == 0 || NSMaxRange(formattingRange.range) > textLength) {
      continue;
    }

    id<ENRMStyleHandler> handler = _styleHandlers[@(formattingRange.type)];
    if (!handler) {
      continue;
    }

    UIFontDescriptorSymbolicTraits traits = [handler fontTraits];
    if (traits != 0) {
      NSUInteger start = formattingRange.range.location;
      NSUInteger end = NSMaxRange(formattingRange.range);
      for (NSUInteger i = start; i < end; i++) {
        traitMap[i] |= traits;
      }
    }

    [handler applyNonFontAttributesToTextStorage:textStorage
                                           range:formattingRange.range
                                 formattingRange:formattingRange
                                           style:style];
  }

  NSUInteger runStart = 0;
  UIFontDescriptorSymbolicTraits currentTraits = traitMap[0];

  for (NSUInteger i = 1; i <= textLength; i++) {
    UIFontDescriptorSymbolicTraits nextTraits = (i < textLength) ? traitMap[i] : ~currentTraits;
    if (nextTraits != currentTraits) {
      if (currentTraits != 0) {
        UIFont *font = [style fontForTraits:currentTraits];
        [textStorage addAttribute:NSFontAttributeName value:font range:NSMakeRange(runStart, i - runStart)];
      }
      runStart = i;
      currentTraits = (i < textLength) ? traitMap[i] : 0;
    }
  }

  free(traitMap);

  // Indent list lines so wrapped text aligns past the marker column; the bullet
  // glyph itself is drawn by the layout manager into the reserved space.
  NSString *plainString = textStorage.string;
  [textStorage enumerateAttribute:ENRMBlockTypeAttributeName
                          inRange:fullTextRange
                          options:0
                       usingBlock:^(id value, NSRange attrRange, BOOL *stop) {
                         if (!value || [value integerValue] != ENRMInputBlockTypeUnorderedListItem) {
                           return;
                         }
                         NSNumber *depthValue = [textStorage attribute:ENRMListDepthAttributeName
                                                               atIndex:attrRange.location
                                                        effectiveRange:NULL];
                         NSInteger depth = depthValue ? depthValue.integerValue : 0;
                         CGFloat indent = depth * ENRMListIndentPerDepth + ENRMListMarkerWidth;

                         NSMutableParagraphStyle *paragraph = [[NSMutableParagraphStyle alloc] init];
                         paragraph.firstLineHeadIndent = indent;
                         paragraph.headIndent = indent;

                         NSRange paragraphRange = [plainString paragraphRangeForRange:attrRange];
                         [textStorage addAttribute:NSParagraphStyleAttributeName value:paragraph range:paragraphRange];
                       }];

  [textStorage endEditing];

  NSLayoutManager *layoutManager = textStorage.layoutManagers.firstObject;
  if (layoutManager) {
    [layoutManager invalidateLayoutForCharacterRange:fullTextRange actualCharacterRange:NULL];
    [layoutManager ensureLayoutForCharacterRange:fullTextRange];
  }

  ENRMSetNeedsDisplay(textView);
}

@end
