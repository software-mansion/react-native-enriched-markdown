#import "ENRMInputFormatter.h"
#import "ENRMBlockHandler.h"
#import "ENRMBoldStyleHandler.h"
#import "ENRMHeadingBlockHandler.h"
#import "ENRMItalicStyleHandler.h"
#import "ENRMLinkStyleHandler.h"
#import "ENRMSpoilerStyleHandler.h"
#import "ENRMStrikethroughStyleHandler.h"
#import "ENRMStyleHandler.h"
#import "ENRMUnderlineStyleHandler.h"
#import "FontUtils.h"

@implementation ENRMInputLinkVariantStyle
@end

/// Default font-size multipliers applied to the base font when a heading level
/// has no explicit fontSize prop. Indexed by level 1-6 (index 0 unused).
static const CGFloat kDefaultHeadingScale[] = {0.0, 2.0, 1.5, 1.17, 1.0, 0.83, 0.67};

@implementation ENRMInputFormatterStyle {
  NSMutableDictionary<NSNumber *, UIFont *> *_fontCache;
  UIFont *_lastBaseFont;
  // Per-level heading config, indexed 1-6. 0 size means "derive from base font".
  CGFloat _headingFontSizes[7];
  NSString *_headingFontWeights[7];
  RCTUIColor *_headingColors[7];
  UIFont *_headingFontCache[7];
}

- (instancetype)init
{
  if (self = [super init]) {
    _baseFont = [UIFont systemFontOfSize:16.0];
    _baseTextColor = [RCTUIColor labelColor];
    _linkVariants = @[];
    _fontCache = [NSMutableDictionary dictionary];
    for (NSInteger level = 0; level <= 6; level++) {
      _headingFontSizes[level] = 0.0;
      _headingFontWeights[level] = nil;
      _headingColors[level] = nil;
    }
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
  for (NSInteger level = 1; level <= 6; level++) {
    [copy setHeadingFontSize:_headingFontSizes[level] forLevel:level];
    [copy setHeadingFontWeight:_headingFontWeights[level] forLevel:level];
    [copy setHeadingColor:_headingColors[level] forLevel:level];
  }
  return copy;
}

- (BOOL)isValidHeadingLevel:(NSInteger)level
{
  return level >= 1 && level <= 6;
}

- (void)setHeadingFontSize:(CGFloat)fontSize forLevel:(NSInteger)level
{
  if ([self isValidHeadingLevel:level]) {
    _headingFontSizes[level] = fontSize;
    _headingFontCache[level] = nil;
  }
}

- (void)setHeadingFontWeight:(NSString *)fontWeight forLevel:(NSInteger)level
{
  if ([self isValidHeadingLevel:level]) {
    _headingFontWeights[level] = [fontWeight copy];
    _headingFontCache[level] = nil;
  }
}

- (void)setHeadingColor:(RCTUIColor *)color forLevel:(NSInteger)level
{
  if ([self isValidHeadingLevel:level]) {
    _headingColors[level] = color;
  }
}

- (RCTUIColor *)headingColorForLevel:(NSInteger)level
{
  return [self isValidHeadingLevel:level] ? _headingColors[level] : nil;
}

- (UIFont *)headingFontForLevel:(NSInteger)level
{
  if (![self isValidHeadingLevel:level]) {
    return _baseFont;
  }

  [self invalidateCacheIfNeeded];

  UIFont *cached = _headingFontCache[level];
  if (cached) {
    return cached;
  }

  CGFloat size = _headingFontSizes[level];
  if (size <= 0.0) {
    size = _baseFont.pointSize * kDefaultHeadingScale[level];
  }

  NSString *weightString = _headingFontWeights[level];
  UIFont *font = weightString.length > 0 ? [UIFont systemFontOfSize:size weight:ENRMFontWeightFromString(weightString)]
                                         : [_baseFont fontWithSize:size];
  _headingFontCache[level] = font;
  return font;
}

- (void)clearHeadingFontCache
{
  for (NSInteger level = 0; level <= 6; level++) {
    _headingFontCache[level] = nil;
  }
}

- (void)invalidateCacheIfNeeded
{
  if (_lastBaseFont != _baseFont) {
    [_fontCache removeAllObjects];
    [self clearHeadingFontCache];
    _lastBaseFont = _baseFont;
  }
}

- (void)invalidateFontCache
{
  [_fontCache removeAllObjects];
  [self clearHeadingFontCache];
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
  NSDictionary<NSNumber *, id<ENRMBlockHandler>> *_blockHandlers;
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

    ENRMHeadingBlockHandler *headingHandler = [[ENRMHeadingBlockHandler alloc] init];
    NSMutableDictionary<NSNumber *, id<ENRMBlockHandler>> *blockMap = [NSMutableDictionary dictionary];
    for (NSInteger level = 1; level <= 6; level++) {
      blockMap[@(ENRMBlockTypeForHeadingLevel(level))] = headingHandler;
    }
    _blockHandlers = [blockMap copy];
  }
  return self;
}

- (nullable id<ENRMStyleHandler>)handlerForStyleType:(ENRMInputStyleType)type
{
  return _styleHandlers[@(type)];
}

- (nullable id<ENRMBlockHandler>)handlerForBlockType:(ENRMInputBlockType)type
{
  return _blockHandlers[@(type)];
}

- (void)applyFormattingRanges:(NSArray<ENRMFormattingRange *> *)ranges
                   toTextView:(ENRMPlatformTextView *)textView
                        style:(ENRMInputFormatterStyle *)style
{
  [self applyFormattingRanges:ranges
                   toTextView:textView
                        style:style
                scopedToRange:NSMakeRange(0, textView.textStorage.length)];
}

- (void)applyFormattingRanges:(NSArray<ENRMFormattingRange *> *)ranges
                   toTextView:(ENRMPlatformTextView *)textView
                        style:(ENRMInputFormatterStyle *)style
                scopedToRange:(NSRange)scope
{
  NSTextStorage *textStorage = textView.textStorage;
  NSUInteger textLength = textStorage.length;

  if (textLength == 0) {
    return;
  }

  NSUInteger scopeStart = MIN(scope.location, textLength);
  NSUInteger scopeEnd = MIN(NSMaxRange(scope), textLength);
  if (scopeEnd <= scopeStart) {
    return;
  }
  NSRange scopeRange = NSMakeRange(scopeStart, scopeEnd - scopeStart);
  NSUInteger scopeLength = scopeRange.length;

  [textStorage beginEditing];

  [textStorage addAttribute:NSFontAttributeName value:style.baseFont range:scopeRange];
  [textStorage addAttribute:NSForegroundColorAttributeName value:style.baseTextColor range:scopeRange];
  [textStorage removeAttribute:NSUnderlineStyleAttributeName range:scopeRange];
  [textStorage removeAttribute:NSStrikethroughStyleAttributeName range:scopeRange];
  [textStorage removeAttribute:NSBackgroundColorAttributeName range:scopeRange];

  UIFontDescriptorSymbolicTraits *traitMap =
      (UIFontDescriptorSymbolicTraits *)calloc(scopeLength, sizeof(UIFontDescriptorSymbolicTraits));
  if (!traitMap) {
    [textStorage endEditing];
    return;
  }

  for (ENRMFormattingRange *formattingRange in ranges) {
    if (formattingRange.range.length == 0 || NSMaxRange(formattingRange.range) > textLength) {
      continue;
    }

    // Ranges straddling the scope boundary are clipped: attributes are
    // per-character and the out-of-scope part is untouched by the reset above.
    NSRange clipped = NSIntersectionRange(formattingRange.range, scopeRange);
    if (clipped.length == 0) {
      continue;
    }

    id<ENRMStyleHandler> handler = _styleHandlers[@(formattingRange.type)];
    if (!handler) {
      continue;
    }

    UIFontDescriptorSymbolicTraits traits = [handler fontTraits];
    if (traits != 0) {
      NSUInteger start = clipped.location;
      NSUInteger end = NSMaxRange(clipped);
      for (NSUInteger i = start; i < end; i++) {
        traitMap[i - scopeStart] |= traits;
      }
    }

    [handler applyNonFontAttributesToTextStorage:textStorage range:clipped formattingRange:formattingRange style:style];
  }

  NSUInteger runStart = 0;
  UIFontDescriptorSymbolicTraits currentTraits = traitMap[0];

  for (NSUInteger i = 1; i <= scopeLength; i++) {
    UIFontDescriptorSymbolicTraits nextTraits = (i < scopeLength) ? traitMap[i] : ~currentTraits;
    if (nextTraits != currentTraits) {
      if (currentTraits != 0) {
        UIFont *font = [style fontForTraits:currentTraits];
        [textStorage addAttribute:NSFontAttributeName
                            value:font
                            range:NSMakeRange(scopeStart + runStart, i - runStart)];
      }
      runStart = i;
      currentTraits = (i < scopeLength) ? traitMap[i] : 0;
    }
  }

  free(traitMap);

  [textStorage endEditing];

  NSLayoutManager *layoutManager = textStorage.layoutManagers.firstObject;
  if (layoutManager) {
    [layoutManager invalidateLayoutForCharacterRange:scopeRange actualCharacterRange:NULL];
    [layoutManager ensureLayoutForCharacterRange:scopeRange];
  }

  ENRMSetNeedsDisplay(textView);
}

- (void)applyBlockRanges:(NSArray<ENRMBlockRange *> *)blockRanges
              toTextView:(ENRMPlatformTextView *)textView
                   style:(ENRMInputFormatterStyle *)style
{
  [self applyBlockRanges:blockRanges
              toTextView:textView
                   style:style
           scopedToRange:NSMakeRange(0, textView.textStorage.length)];
}

- (void)applyBlockRanges:(NSArray<ENRMBlockRange *> *)blockRanges
              toTextView:(ENRMPlatformTextView *)textView
                   style:(ENRMInputFormatterStyle *)style
           scopedToRange:(NSRange)scope
{
  if (_blockHandlers.count == 0) {
    return;
  }

  NSTextStorage *textStorage = textView.textStorage;
  NSUInteger textLength = textStorage.length;
  if (textLength == 0) {
    return;
  }

  NSUInteger scopeStart = MIN(scope.location, textLength);
  NSUInteger scopeEnd = MIN(NSMaxRange(scope), textLength);
  if (scopeEnd <= scopeStart) {
    return;
  }
  NSRange scopeRange = NSMakeRange(scopeStart, scopeEnd - scopeStart);

  [textStorage beginEditing];

  // Reset pass: strip everything the previous block pass applied — paragraphs
  // are found via the ENRMBlockTypeAttributeName marker — so a removed or moved
  // block doesn't leave stale paragraph styling behind. Character-level
  // attributes (fonts, colors) are already reset by the inline pass, which runs
  // first. This runs even with zero current ranges: deleting the last block
  // must still clear its styling.
  NSMutableArray<NSValue *> *previouslyClaimedRanges = [NSMutableArray array];
  [textStorage enumerateAttribute:ENRMBlockTypeAttributeName
                          inRange:scopeRange
                          options:0
                       usingBlock:^(id value, NSRange range, BOOL *stop) {
                         if (value != nil) {
                           [previouslyClaimedRanges addObject:[NSValue valueWithRange:range]];
                         }
                       }];
  for (NSValue *rangeValue in previouslyClaimedRanges) {
    NSRange range = rangeValue.rangeValue;
    [textStorage removeAttribute:ENRMBlockTypeAttributeName range:range];
    [textStorage removeAttribute:ENRMBlockLevelAttributeName range:range];
    [textStorage removeAttribute:NSParagraphStyleAttributeName range:range];
  }

  for (ENRMBlockRange *blockRange in blockRanges) {
    if (blockRange.range.length == 0 || NSMaxRange(blockRange.range) > textLength) {
      continue;
    }

    // Blocks are line-scoped and the scope covers whole lines, so a block
    // either lies fully inside the scope or fully outside it.
    if (NSIntersectionRange(blockRange.range, scopeRange).length == 0) {
      continue;
    }

    id<ENRMBlockHandler> handler = _blockHandlers[@(blockRange.type)];
    if (!handler) {
      continue;
    }

    // Seed from the paragraph style at the block's location. This only matters
    // for newly claimed paragraphs that carry a base style — for re-claimed
    // paragraphs the reset pass above just cleared the attribute, so this reads
    // the default. That's fine: handlers set absolute values, and
    // applyWritingDirection re-derives direction after this pass.
    NSParagraphStyle *existingStyle = [textStorage attribute:NSParagraphStyleAttributeName
                                                     atIndex:blockRange.range.location
                                              effectiveRange:NULL];
    NSMutableParagraphStyle *paragraphStyle =
        existingStyle ? [existingStyle mutableCopy] : [[NSMutableParagraphStyle alloc] init];
    NSMutableDictionary<NSAttributedStringKey, id> *attributes = [NSMutableDictionary dictionary];

    [handler applyAttributesToParagraphStyle:paragraphStyle attributes:attributes blockRange:blockRange style:style];

    attributes[NSParagraphStyleAttributeName] = paragraphStyle;
    attributes[ENRMBlockTypeAttributeName] = @(blockRange.type);
    attributes[ENRMBlockLevelAttributeName] = @(blockRange.level);

    // Merge block font size onto each run, preserving inline bold/italic traits.
    UIFont *blockFont = attributes[NSFontAttributeName];
    if (blockFont) {
      [attributes removeObjectForKey:NSFontAttributeName];
      [self mergeFontSize:blockFont overRange:blockRange.range inTextStorage:textStorage];
    }

    [textStorage addAttributes:attributes range:blockRange.range];
  }

  [textStorage endEditing];

  ENRMSetNeedsDisplay(textView);
}

/// Applies `blockFont` over `range` while preserving the symbolic traits already
/// present on each existing font run (set by the inline formatting pass). The
/// resulting font takes its size and descriptor from `blockFont` but unions in
/// the run's traits, so inline bold/italic survives the block's size change.
- (void)mergeFontSize:(UIFont *)blockFont overRange:(NSRange)range inTextStorage:(NSTextStorage *)textStorage
{
  UIFontDescriptorSymbolicTraits blockTraits = blockFont.fontDescriptor.symbolicTraits;

  [textStorage enumerateAttribute:NSFontAttributeName
                          inRange:range
                          options:0
                       usingBlock:^(UIFont *_Nullable runFont, NSRange runRange, BOOL *_Nonnull stop) {
                         UIFontDescriptorSymbolicTraits runTraits = runFont ? runFont.fontDescriptor.symbolicTraits : 0;
                         UIFontDescriptorSymbolicTraits mergedTraits = blockTraits | runTraits;

                         UIFont *resolved = blockFont;
                         if (mergedTraits != blockTraits) {
                           UIFontDescriptor *descriptor =
                               [blockFont.fontDescriptor fontDescriptorWithSymbolicTraits:mergedTraits];
                           if (descriptor) {
                             resolved = [UIFont fontWithDescriptor:descriptor size:0];
                           }
                         }
                         [textStorage addAttribute:NSFontAttributeName value:resolved range:runRange];
                       }];
}

@end
