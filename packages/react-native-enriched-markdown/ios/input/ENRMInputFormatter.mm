#import "ENRMInputFormatter.h"
#import "ENRMBlockHandler.h"
#import "ENRMBoldStyleHandler.h"
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

    // Block handlers are registered here as concrete block types are added.
    // Empty in PR1: with no handler registered, every paragraph stays a plain
    // paragraph and the block pipeline is a no-op.
    NSArray<id<ENRMBlockHandler>> *blockHandlers = @[];
    NSMutableDictionary<NSNumber *, id<ENRMBlockHandler>> *blockMap = [NSMutableDictionary dictionary];
    for (id<ENRMBlockHandler> handler in blockHandlers) {
      blockMap[@(handler.blockType)] = handler;
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

  [textStorage endEditing];

  NSLayoutManager *layoutManager = textStorage.layoutManagers.firstObject;
  if (layoutManager) {
    [layoutManager invalidateLayoutForCharacterRange:fullTextRange actualCharacterRange:NULL];
    [layoutManager ensureLayoutForCharacterRange:fullTextRange];
  }

  ENRMSetNeedsDisplay(textView);
}

- (void)applyBlockRanges:(NSArray<ENRMBlockRange *> *)blockRanges
              toTextView:(ENRMPlatformTextView *)textView
                   style:(ENRMInputFormatterStyle *)style
{
  if (_blockHandlers.count == 0) {
    return;
  }

  NSTextStorage *textStorage = textView.textStorage;
  NSUInteger textLength = textStorage.length;
  if (textLength == 0) {
    return;
  }

  [textStorage beginEditing];

  // Reset pass: strip everything the previous block pass applied — paragraphs
  // are found via the ENRMBlockTypeAttributeName marker — so a removed or moved
  // block doesn't leave stale paragraph styling behind. Character-level
  // attributes (fonts, colors) are already reset by the inline pass, which runs
  // first. This runs even with zero current ranges: deleting the last block
  // must still clear its styling.
  NSMutableArray<NSValue *> *previouslyClaimedRanges = [NSMutableArray array];
  [textStorage enumerateAttribute:ENRMBlockTypeAttributeName
                          inRange:NSMakeRange(0, textLength)
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
    [textStorage addAttributes:attributes range:blockRange.range];
  }

  [textStorage endEditing];

  ENRMSetNeedsDisplay(textView);
}

@end
