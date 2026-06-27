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

/// Size multipliers applied to the base font for each heading level. Tuned to
/// read as a clear hierarchy in-editor; the readonly renderer's StyleConfig can
/// override these once heading style props are plumbed through.
static CGFloat headingScaleForLevel(NSInteger level)
{
  switch (level) {
    case 1:
      return 1.6;
    case 2:
      return 1.4;
    case 3:
      return 1.2;
    default:
      return 1.0;
  }
}

- (UIFont *)baseFontForHeadingLevel:(NSInteger)level
{
  if (level <= 0) {
    return _baseFont;
  }
  CGFloat size = _baseFont.pointSize * headingScaleForLevel(level);
  UIFontDescriptorSymbolicTraits traits = _baseFont.fontDescriptor.symbolicTraits | UIFontDescriptorTraitBold;
  UIFontDescriptor *descriptor = [_baseFont.fontDescriptor fontDescriptorWithSymbolicTraits:traits];
  return descriptor ? [UIFont fontWithDescriptor:descriptor size:size] : [_baseFont fontWithSize:size];
}

- (UIFont *)fontForTraits:(UIFontDescriptorSymbolicTraits)traits headingLevel:(NSInteger)level
{
  if (level <= 0) {
    return [self fontForTraits:traits];
  }
  UIFont *base = [self baseFontForHeadingLevel:level];
  UIFontDescriptorSymbolicTraits effective = base.fontDescriptor.symbolicTraits | traits;
  if (effective == base.fontDescriptor.symbolicTraits) {
    return base;
  }
  UIFontDescriptor *descriptor = [base.fontDescriptor fontDescriptorWithSymbolicTraits:effective];
  return descriptor ? [UIFont fontWithDescriptor:descriptor size:base.pointSize] : base;
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

  [textStorage addAttribute:NSForegroundColorAttributeName value:style.baseTextColor range:fullTextRange];
  [textStorage removeAttribute:NSUnderlineStyleAttributeName range:fullTextRange];
  [textStorage removeAttribute:NSStrikethroughStyleAttributeName range:fullTextRange];
  [textStorage removeAttribute:NSBackgroundColorAttributeName range:fullTextRange];

  UIFontDescriptorSymbolicTraits *traitMap =
      (UIFontDescriptorSymbolicTraits *)calloc(textLength, sizeof(UIFontDescriptorSymbolicTraits));
  // Per-character heading level, read from the block attribute TextKit migrates
  // across edits. Drives both the base font size and the run boundaries below.
  NSInteger *headingMap = (NSInteger *)calloc(textLength, sizeof(NSInteger));
  if (!traitMap || !headingMap) {
    free(traitMap);
    free(headingMap);
    [textStorage endEditing];
    return;
  }

  [textStorage enumerateAttribute:ENRMBlockTypeAttributeName
                          inRange:fullTextRange
                          options:0
                       usingBlock:^(id value, NSRange attrRange, BOOL *stop) {
                         if (!value) {
                           return;
                         }
                         NSInteger level = ENRMHeadingLevelForBlockType((ENRMInputBlockType)[value integerValue]);
                         if (level <= 0) {
                           return;
                         }
                         for (NSUInteger i = attrRange.location; i < NSMaxRange(attrRange); i++) {
                           headingMap[i] = level;
                         }
                       }];

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

  // Emit font runs keyed by (traits, heading level). Unlike the inline-only
  // path, a heading run with no inline traits still needs its own (larger) font,
  // so plain runs are no longer skipped.
  NSUInteger runStart = 0;
  for (NSUInteger i = 1; i <= textLength; i++) {
    BOOL boundary = (i == textLength) || traitMap[i] != traitMap[i - 1] || headingMap[i] != headingMap[i - 1];
    if (!boundary) {
      continue;
    }
    UIFontDescriptorSymbolicTraits traits = traitMap[runStart];
    NSInteger level = headingMap[runStart];
    UIFont *font = (traits == 0 && level == 0) ? style.baseFont : [style fontForTraits:traits headingLevel:level];
    [textStorage addAttribute:NSFontAttributeName value:font range:NSMakeRange(runStart, i - runStart)];
    runStart = i;
  }

  free(traitMap);
  free(headingMap);

  [textStorage endEditing];

  NSLayoutManager *layoutManager = textStorage.layoutManagers.firstObject;
  if (layoutManager) {
    [layoutManager invalidateLayoutForCharacterRange:fullTextRange actualCharacterRange:NULL];
    [layoutManager ensureLayoutForCharacterRange:fullTextRange];
  }

  ENRMSetNeedsDisplay(textView);
}

@end
