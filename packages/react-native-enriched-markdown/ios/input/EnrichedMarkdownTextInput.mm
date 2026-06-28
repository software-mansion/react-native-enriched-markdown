#import "EnrichedMarkdownTextInput.h"
#import "ContextMenuUtils.h"
#import "ENRMAutoLinkDetector.h"
#import "ENRMDetectorPipeline.h"
#import "ENRMFormattingRange.h"
#import "ENRMFormattingStore.h"
#import "ENRMInputBlockType.h"
#import "ENRMInputFormatter.h"
#import "ENRMInputLayoutManager.h"
#import "ENRMInputLinkPrompt.h"
#import "ENRMInputMentionCandidate.h"
#import "ENRMInputParser.h"
#import "ENRMInputTextView.h"
#import "ENRMLinkRegexConfig.h"
#import "ENRMMarkdownSerializer.h"
#import "ENRMStyleHandler.h"
#import "ENRMStyleMergingConfig.h"
#import "ENRMUIKit.h"
#import "ENRMWordsUtils.h"
#import "EnrichedMarkdownTextInput+Internal.h"
#import "InputStylePropsUtils.h"
#import "ParagraphStyleUtils.h"
#import "SelectionColorUtils.h"
#import <QuartzCore/CABase.h>
#import <React/RCTI18nUtil.h>
#if TARGET_OS_OSX
#import <React/RCTBackedTextInputDelegate.h>
#endif

#import <ReactNativeEnrichedMarkdown/EnrichedMarkdownTextInputComponentDescriptor.h>
#import <ReactNativeEnrichedMarkdown/EventEmitters.h>
#import <ReactNativeEnrichedMarkdown/Props.h>
#import <ReactNativeEnrichedMarkdown/RCTComponentViewHelpers.h>

#import "EnrichedMarkdownTextInputShadowNode.h"
#import "HeightUpdateUtils.h"
#import "RCTFabricComponentsPlugins.h"
#import <React/RCTConversions.h>

using namespace facebook::react;

#if !TARGET_OS_OSX
@interface EnrichedMarkdownTextInput () <RCTEnrichedMarkdownTextInputViewProtocol, UITextViewDelegate>
#else
@interface EnrichedMarkdownTextInput () <RCTEnrichedMarkdownTextInputViewProtocol, RCTBackedTextInputDelegate>
#endif
- (void)setupTextView;
- (void)applyFormatting;
- (void)toggleInlineStyle:(ENRMInputStyleType)styleType;
- (void)resetBaseTypingAttributes;
@end

@implementation EnrichedMarkdownTextInput {
  ENRMPlatformTextView *_textView;
  ENRMInputLayoutManager *_layoutManager;
  EnrichedMarkdownTextInputShadowNode::ConcreteState::Shared _state;
  int _heightUpdateCounter;
  ENRMInputFormatter *_formatter;
  ENRMInputFormatterStyle *_formatterStyle;
  ENRMFormattingStore *_formattingStore;
  NSMutableSet<NSNumber *> *_pendingStyles;
  NSMutableSet<NSNumber *> *_pendingStyleRemovals;
  BOOL _isApplyingFormatting;
  BOOL _isTextChanging;
  BOOL _emitMarkdown;
  CFTimeInterval _lastTextChangeTime;

  ENRMPlaceholderLabel *_placeholderLabel;

  NSUInteger _lastTextLength;
  NSRange _lastSelectedRange;
  NSRange _preEditSelectedRange;

  struct {
    BOOL bold, italic, underline, strikethrough, spoiler, link, unorderedList, initialized;
  } _prevState;

  // List kind/depth the next typed character should adopt when the cursor sits on
  // an empty line (no character holds the block attribute yet).
  ENRMInputBlockType _pendingBlockType;
  NSInteger _pendingListDepth;

  // Set when the pending block kind was established for an empty line (list
  // toggled on, or a list continued onto a fresh line by Return). While set, a
  // selection change on that still-empty line must NOT clear the pending kind —
  // it is the only thing keeping the marker alive until the first character is
  // typed. Cleared once a glyph lands (the attribute then lives on real text) or
  // the caret leaves the empty line. Without this, a selection event arriving
  // after the post-edit grace window (more likely under heavier app load) wipes
  // the pending kind and the continued bullet is lost.
  BOOL _keepPendingBlockOnEmptyLine;

  // Block kind/depth of the edited line captured before a text change, so it can
  // be restored if the edit (e.g. autocorrect) replaced the attribute-bearing
  // characters.
  ENRMInputBlockType _preEditBlockType;
  NSInteger _preEditListDepth;

  // Length of text the pending edit will replace (range.length from
  // shouldChangeTextInRange). A non-zero value means existing characters — which
  // may carry the line's block attribute — are being overwritten, as with
  // autocorrect or paste. handleTextChanged models edits off the caret selection
  // and underestimates the inserted span for such replacements, so it heals the
  // line's block attribute separately when this is set.
  NSUInteger _preEditReplacementLength;
  BOOL _preEditReplacementHasNewline;

  std::optional<CGRect> _prevCaretRect;

#if TARGET_OS_OSX
  NSScrollView *_scrollView;
#endif

  NSArray<NSString *> *_contextMenuItemTexts;
  NSArray<NSString *> *_contextMenuItemIcons;
  NSArray<NSString *> *_mentionIndicators;
  NSString *_activeMentionIndicator;
  NSRange _activeMentionRange;
  NSString *_activeMentionText;

  ENRMAutoLinkDetector *_autoLinkDetector;
  ENRMDetectorPipeline *_detectorPipeline;

  ENRMWritingDirectionMode _writingDirectionMode;
  NSWritingDirection _resolvedLayoutDirection;

  ENRMInputSelectionMenuConfig _inputSelectionMenuConfig;
  ENRMFormatMenuConfig _formatMenuConfig;
}

#pragma mark - Fabric lifecycle

+ (ComponentDescriptorProvider)componentDescriptorProvider
{
  return concreteComponentDescriptorProvider<EnrichedMarkdownTextInputComponentDescriptor>();
}

+ (BOOL)shouldBeRecycled
{
  return NO;
}

- (instancetype)initWithFrame:(CGRect)frame
{
  if (self = [super initWithFrame:frame]) {
    static const auto defaultProps = std::make_shared<const EnrichedMarkdownTextInputProps>();
    _props = defaultProps;

    self.backgroundColor = [RCTUIColor clearColor];
    _blockEmitting = NO;
    _heightUpdateCounter = 0;
    _formatter = [[ENRMInputFormatter alloc] init];
    _formatterStyle = [[ENRMInputFormatterStyle alloc] init];
    _formattingStore = [[ENRMFormattingStore alloc] init];
    _pendingStyles = [NSMutableSet set];
    _pendingStyleRemovals = [NSMutableSet set];
    _lastTextLength = 0;
    _lastSelectedRange = NSMakeRange(0, 0);
    _mentionIndicators = @[];
    _activeMentionRange = NSMakeRange(NSNotFound, 0);
    _activeMentionText = @"";

    _writingDirectionMode = ENRMWritingDirectionModeFirstStrong;
    _resolvedLayoutDirection =
        [[RCTI18nUtil sharedInstance] isRTL] ? NSWritingDirectionRightToLeft : NSWritingDirectionLeftToRight;
    _inputSelectionMenuConfig = (ENRMInputSelectionMenuConfig){.format = YES, .copyAsMarkdown = YES};
    _formatMenuConfig = (ENRMFormatMenuConfig){
        .bold = YES, .italic = YES, .underline = YES, .strikethrough = YES, .spoiler = YES, .link = YES};

    [self setupTextView];

    [self setupDetectorPipeline];
  }
  return self;
}

- (void)setupDetectorPipeline
{
  _autoLinkDetector = [[ENRMAutoLinkDetector alloc] initWithTextStorage:_textView.textStorage
                                                        formattingStore:_formattingStore
                                                                  style:_formatterStyle];

  __weak EnrichedMarkdownTextInput *weakSelf = self;
  _autoLinkDetector.onLinkDetected = ^(NSString *text, NSString *url, NSRange range) {
    [weakSelf emitOnLinkDetectedWithText:text url:url range:range];
  };

  _detectorPipeline = [[ENRMDetectorPipeline alloc] init];
  [_detectorPipeline addDetector:_autoLinkDetector];
}

- (void)setupTextView
{
#if !TARGET_OS_OSX
  _layoutManager = [[ENRMInputLayoutManager alloc] init];
  NSTextContainer *textContainer = [[NSTextContainer alloc] initWithSize:CGSizeMake(0, CGFLOAT_MAX)];
  textContainer.widthTracksTextView = YES;
  [_layoutManager addTextContainer:textContainer];

  NSTextStorage *textStorage = [[NSTextStorage alloc] init];
  [textStorage addLayoutManager:_layoutManager];

  ENRMInputTextView *inputTextView = [[ENRMInputTextView alloc] initWithFrame:CGRectZero textContainer:textContainer];
#else
  ENRMInputTextView *inputTextView = [[ENRMInputTextView alloc] initWithFrame:CGRectZero];
#endif
  inputTextView.markdownTextInput = self;
  _textView = inputTextView;
  ENRMConfigureMarkdownTextInputTextView(_textView);
#if !TARGET_OS_OSX
  _textView.adjustsFontForContentSizeCategory = YES;
  _textView.delegate = self;
#else
  _textView.textInputDelegate = self;
#endif

#if !TARGET_OS_OSX
  self.contentView = _textView;
#else
  _textView.selectable = YES;

  _scrollView = [[NSScrollView alloc] initWithFrame:CGRectZero];
  _scrollView.backgroundColor = [RCTUIColor clearColor];
  _scrollView.drawsBackground = NO;
  _scrollView.borderType = NSNoBorder;
  _scrollView.hasHorizontalRuler = NO;
  _scrollView.hasVerticalRuler = NO;
  _scrollView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;

  _textView.verticallyResizable = YES;
  _textView.horizontallyResizable = YES;
  _textView.textContainer.containerSize = NSMakeSize(CGFLOAT_MAX, CGFLOAT_MAX);
  _textView.textContainer.widthTracksTextView = YES;

  _scrollView.documentView = _textView;
  self.contentView = _scrollView;
#endif

  _placeholderLabel = ENRMCreatePlaceholderLabel(_textView, _formatterStyle.baseFont);
#if !TARGET_OS_OSX
  _placeholderLabel.adjustsFontForContentSizeCategory = YES;
#endif

  [self resetBaseTypingAttributes];
}

#pragma mark - State

- (void)updateState:(const facebook::react::State::Shared &)state
           oldState:(const facebook::react::State::Shared &)oldState
{
  _state = std::static_pointer_cast<const EnrichedMarkdownTextInputShadowNode::ConcreteState>(state);

  if (oldState == nullptr) {
    [self requestHeightUpdate];
  }
}

- (void)requestHeightUpdate
{
  ENRMRequestHeightUpdate<EnrichedMarkdownTextInputState>(_state, _heightUpdateCounter, self);
}

/// Yoga-resolved direction inherited from any ancestor `direction` style.
/// In FirstStrong mode this feeds the neutral-paragraph fallback, so a change
/// requires re-resolving per-paragraph directions over the current text.
- (void)updateLayoutMetrics:(const LayoutMetrics &)layoutMetrics
           oldLayoutMetrics:(const LayoutMetrics &)oldLayoutMetrics
{
  [super updateLayoutMetrics:layoutMetrics oldLayoutMetrics:oldLayoutMetrics];

  NSWritingDirection resolved = _resolvedLayoutDirection;
  if (layoutMetrics.layoutDirection == LayoutDirection::RightToLeft) {
    resolved = NSWritingDirectionRightToLeft;
  } else if (layoutMetrics.layoutDirection == LayoutDirection::LeftToRight) {
    resolved = NSWritingDirectionLeftToRight;
  }

  if (resolved != _resolvedLayoutDirection) {
    _resolvedLayoutDirection = resolved;
    if (_writingDirectionMode == ENRMWritingDirectionModeFirstStrong && _textView.textStorage.length > 0) {
      [self applyFormatting];
    }
  }
}

#pragma mark - Measurement

- (CGSize)measureSize:(CGFloat)maxWidth
{
  NSMutableAttributedString *measuredText =
      [[NSMutableAttributedString alloc] initWithAttributedString:ENRMGetAttributedText(_textView)];

  // Empty input should still be the height of a single line.
  // Use typingAttributes so the measurement matches the actual configured font.
  if (measuredText.length == 0) {
    [measuredText appendAttributedString:[[NSAttributedString alloc] initWithString:@"I"
                                                                         attributes:_textView.typingAttributes]];
  }

  // Trailing newlines are not counted by boundingRectWithSize — append
  // a mock character so the extra line is included in the height.
  if (measuredText.length > 0) {
    unichar lastChar = [measuredText.string characterAtIndex:measuredText.length - 1];
    if ([[NSCharacterSet newlineCharacterSet] characterIsMember:lastChar]) {
      [measuredText appendAttributedString:[[NSAttributedString alloc] initWithString:@"I"
                                                                           attributes:_textView.typingAttributes]];
    }
  }

  CGRect boundingBox =
      [measuredText boundingRectWithSize:CGSizeMake(maxWidth, CGFLOAT_MAX)
                                 options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading
                                 context:nil];

  return CGSizeMake(maxWidth, ceil(boundingBox.size.height));
}

#pragma mark - Props

- (void)updateProps:(Props::Shared const &)props oldProps:(Props::Shared const &)oldProps
{
  const auto &oldViewProps = *std::static_pointer_cast<EnrichedMarkdownTextInputProps const>(_props);
  const auto &newViewProps = *std::static_pointer_cast<EnrichedMarkdownTextInputProps const>(props);

  if (newViewProps.editable != oldViewProps.editable) {
    _textView.editable = newViewProps.editable;
  }

#if !TARGET_OS_OSX
  if (newViewProps.scrollEnabled != oldViewProps.scrollEnabled) {
    _textView.scrollEnabled = newViewProps.scrollEnabled;
  }

  if (newViewProps.autoCapitalize != oldViewProps.autoCapitalize) {
    NSString *value = [NSString stringWithUTF8String:newViewProps.autoCapitalize.c_str()];
    _textView.autocapitalizationType = ENRMAutocapitalizationTypeFromString(value);
    if ([_textView isFirstResponder]) {
      [_textView resignFirstResponder];
      [_textView becomeFirstResponder];
    }
  }

  if (newViewProps.multiline != oldViewProps.multiline) {
    _textView.textContainer.maximumNumberOfLines = newViewProps.multiline ? 0 : 1;
    _textView.textContainer.lineBreakMode =
        newViewProps.multiline ? NSLineBreakByWordWrapping : NSLineBreakByTruncatingTail;
  }
#endif

  if (newViewProps.placeholder != oldViewProps.placeholder) {
    ENRMSetPlaceholderText(_placeholderLabel, [NSString stringWithUTF8String:newViewProps.placeholder.c_str()]);
  }

  if (newViewProps.placeholderTextColor != oldViewProps.placeholderTextColor) {
    if (isColorMeaningful(newViewProps.placeholderTextColor)) {
      _placeholderLabel.textColor = RCTUIColorFromSharedColor(newViewProps.placeholderTextColor);
    }
  }

  if (newViewProps.cursorColor != oldViewProps.cursorColor) {
    if (isColorMeaningful(newViewProps.cursorColor)) {
      ENRMSetCursorColor(_textView, RCTUIColorFromSharedColor(newViewProps.cursorColor));
    }
  }

  if (newViewProps.selectionColor != oldViewProps.selectionColor) {
    ENRMApplySelectionColor(_textView, newViewProps.selectionColor);
  }

  _emitMarkdown = newViewProps.isOnChangeMarkdownSet;

  {
    auto configFromProp = [](const auto &prop) {
      return [[ENRMLinkRegexConfig alloc] initWithPattern:[NSString stringWithUTF8String:prop.pattern.c_str()]
                                          caseInsensitive:prop.caseInsensitive
                                                   dotAll:prop.dotAll
                                               isDisabled:prop.isDisabled
                                                isDefault:prop.isDefault];
    };
    ENRMLinkRegexConfig *oldRegexConfig = configFromProp(oldViewProps.linkRegex);
    ENRMLinkRegexConfig *newRegexConfig = configFromProp(newViewProps.linkRegex);
    if (![newRegexConfig isEqualToConfig:oldRegexConfig]) {
      [_autoLinkDetector setRegexConfig:newRegexConfig];
    }
  }

  if (ENRMContextMenuItemsChanged(oldViewProps.contextMenuItems, newViewProps.contextMenuItems)) {
    _contextMenuItemTexts = ENRMContextMenuTextsFromItems(newViewProps.contextMenuItems);
    _contextMenuItemIcons = ENRMContextMenuIconsFromItems(newViewProps.contextMenuItems);
  }

  _inputSelectionMenuConfig = (ENRMInputSelectionMenuConfig){
      .format = newViewProps.selectionMenuConfig.format,
      .copyAsMarkdown = newViewProps.selectionMenuConfig.copyAsMarkdown,
  };

  _formatMenuConfig = (ENRMFormatMenuConfig){
      .bold = newViewProps.formatMenuConfig.bold,
      .italic = newViewProps.formatMenuConfig.italic,
      .underline = newViewProps.formatMenuConfig.underline,
      .strikethrough = newViewProps.formatMenuConfig.strikethrough,
      .spoiler = newViewProps.formatMenuConfig.spoiler,
      .link = newViewProps.formatMenuConfig.link,
  };

  if (newViewProps.mentionIndicators != oldViewProps.mentionIndicators) {
    NSMutableArray<NSString *> *indicators = [NSMutableArray array];
    for (const auto &indicator : newViewProps.mentionIndicators) {
      NSString *value = [NSString stringWithUTF8String:indicator.c_str()];
      if (value.length > 0) {
        [indicators addObject:value];
      }
    }
    _mentionIndicators = [indicators copy];
    if (_activeMentionIndicator != nil && ![_mentionIndicators containsObject:_activeMentionIndicator]) {
      [self clearActiveMention:_activeMentionIndicator];
    }
    [self updateActiveMention];
  }

  BOOL styleChanged = applyInputStyleProps(_formatterStyle, newViewProps, oldViewProps);

  BOOL writingDirectionChanged = NO;
  if (newViewProps.writingDirection != oldViewProps.writingDirection) {
    NSString *value = [[NSString alloc] initWithUTF8String:newViewProps.writingDirection.c_str()];
    _writingDirectionMode = ENRMResolveWritingDirectionMode(value);
    writingDirectionChanged = YES;
  }

  if (newViewProps.defaultValue != oldViewProps.defaultValue) {
    if (!newViewProps.defaultValue.empty() && oldViewProps.defaultValue.empty()) {
      NSString *markdown = [NSString stringWithUTF8String:newViewProps.defaultValue.c_str()];
      [self importMarkdown:markdown];
    }
  }

  if (styleChanged) {
    _placeholderLabel.font = _formatterStyle.baseFont;

    [self resetBaseTypingAttributes];

    if (_formattingStore.allRanges.count > 0) {
      [self applyFormatting];
    }

    [self requestHeightUpdate];
  } else if (writingDirectionChanged && _textView.textStorage.length > 0) {
    [self applyFormatting];
  }

  [super updateProps:props oldProps:oldProps];
}

#pragma mark - Relayout

- (void)scheduleRelayoutIfNeeded
{
  [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_performRelayout) object:nil];
  [self performSelector:@selector(_performRelayout) withObject:nil afterDelay:0];
}

- (void)_performRelayout
{
  if (!_textView) {
    return;
  }

  dispatch_async(dispatch_get_main_queue(), ^{
    NSUInteger textLength = self->_textView.textStorage.length;
    if (textLength == 0) {
      return;
    }
    NSRange wholeRange = NSMakeRange(0, textLength);
    NSRange actualRange = NSMakeRange(0, 0);
    [self->_textView.layoutManager invalidateLayoutForCharacterRange:wholeRange actualCharacterRange:&actualRange];
    [self->_textView.layoutManager ensureLayoutForCharacterRange:actualRange];
    [self->_textView.layoutManager invalidateDisplayForCharacterRange:wholeRange];

    CGSize measuredSize = [self measureSize:self->_textView.frame.size.width];
    ENRMSetContentSize(self->_textView, measuredSize);
  });
}

#pragma mark - Window attachment

- (void)didMoveToWindow
{
  [super didMoveToWindow];

  if (self.window) {
    // Don't override the contentView frame set by RCTViewComponentView.
    ENRMRefreshTextViewLayout(_textView);

    [self applyFormatting];
    [self updatePlaceholderVisibility];
    [self requestHeightUpdate];

    const auto &viewProps = *std::static_pointer_cast<EnrichedMarkdownTextInputProps const>(_props);
    if (viewProps.autoFocus) {
      ENRMFocusTextView(_textView);
    }
  }
}

#if TARGET_OS_OSX

#pragma mark - macOS responder chain

- (BOOL)acceptsFirstResponder
{
  return _textView.acceptsFirstResponder;
}

- (BOOL)becomeFirstResponder
{
  return [self.window makeFirstResponder:_textView];
}

- (BOOL)needsPanelToBecomeKey
{
  return YES;
}

- (BOOL)mouseDownCanMoveWindow
{
  return NO;
}

- (void)mouseDown:(NSEvent *)event
{
  [self.window makeFirstResponder:_textView];
  [_textView mouseDown:event];
}

#endif

#if !TARGET_OS_OSX
- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
  [super traitCollectionDidChange:previousTraitCollection];

  if (previousTraitCollection.preferredContentSizeCategory != self.traitCollection.preferredContentSizeCategory) {
    [_formatterStyle invalidateFontCache];

    [self resetBaseTypingAttributes];

    _placeholderLabel.font = _formatterStyle.baseFont;

    [self applyFormatting];
    [self requestHeightUpdate];
  }
}
#endif

#pragma mark - Placeholder

- (void)updatePlaceholderVisibility
{
  // Hide the placeholder while a bullet is drawn on the empty editor (block just
  // toggled, nothing typed yet) — otherwise the marker overlaps the placeholder.
  BOOL hasText = ENRMGetPlainText(_textView).length > 0;
  BOOL emptyListMarker = !hasText && [self blockTypeForCursorParagraph] == ENRMInputBlockTypeUnorderedListItem;
  _placeholderLabel.hidden = hasText || emptyListMarker;
}

#pragma mark - Markdown import

- (void)importMarkdown:(NSString *)markdown
{
  ENRMInputParser *parser = [[ENRMInputParser alloc] init];
  ENRMParseResult *parsed = [parser parseToPlainTextAndRanges:markdown];

  _blockEmitting = YES;

  _isApplyingFormatting = YES;
  ENRMSetPlainText(_textView, parsed.plainText);
  [self applyBlockRanges:parsed.blockRanges];
  _isApplyingFormatting = NO;

  [_formattingStore setRanges:parsed.formattingRanges];
  _lastTextLength = parsed.plainText.length;
  _lastSelectedRange = _textView.selectedRange;
  [self applyFormatting];
  [self updatePlaceholderVisibility];

  _blockEmitting = NO;
}

- (void)replaceTextInRange:(NSRange)selection
                  withText:(NSString *)text
          formattingRanges:(NSArray<ENRMFormattingRange *> *)ranges
{
  NSUInteger editLocation = selection.location;

  _isApplyingFormatting = YES;
  ENRMReplaceTextInRange(_textView, text, selection);
  _isApplyingFormatting = NO;

  [_formattingStore adjustForEditAtLocation:editLocation deletedLength:selection.length insertedLength:text.length];

  for (ENRMFormattingRange *range in ranges) {
    NSRange shifted = NSMakeRange(range.range.location + editLocation, range.range.length);
    [_formattingStore addRange:[ENRMFormattingRange rangeWithType:range.type range:shifted url:range.url]];
  }

  _lastTextLength = ENRMGetPlainText(_textView).length;
  _lastSelectedRange = _textView.selectedRange;

  [self applyFormatting];

  [_detectorPipeline processTextChange:ENRMGetPlainText(_textView)
                     modificationRange:NSMakeRange(editLocation, text.length)];

  [self updatePlaceholderVisibility];
  [self emitOnChangeText];
  [self emitOnChangeSelection];
  [self emitFormattingChanged];
  [self requestHeightUpdate];
  [self scheduleRelayoutIfNeeded];
}

- (void)replaceSelectedTextWith:(NSString *)text formattingRanges:(NSArray<ENRMFormattingRange *> *)ranges
{
  [self replaceTextInRange:_textView.selectedRange withText:text formattingRanges:ranges];
}

- (void)pasteMarkdown:(NSString *)markdown
{
  ENRMInputParser *parser = [[ENRMInputParser alloc] init];
  ENRMParseResult *parsed = [parser parseToPlainTextAndRanges:markdown];
  [self replaceSelectedTextWith:parsed.plainText formattingRanges:parsed.formattingRanges];
}

#pragma mark - Formatting

- (void)resetBaseTypingAttributes
{
  ENRMSetDefaultTypingAttributes(_textView, @{
    NSFontAttributeName : _formatterStyle.baseFont,
    NSForegroundColorAttributeName : _formatterStyle.baseTextColor,
  });
}

- (void)applyFormatting
{
  if (_isApplyingFormatting) {
    return;
  }
  if (ENRMHasMarkedText(_textView)) {
    return;
  }
  _isApplyingFormatting = YES;

  NSRange savedSelection = _textView.selectedRange;

  [_formatter applyFormattingRanges:_formattingStore.allRanges toTextView:_textView style:_formatterStyle];
  [_detectorPipeline refreshAllStyling];
  [self applyWritingDirection];

  NSUInteger textLen = ENRMGetPlainText(_textView).length;
  if (savedSelection.location + savedSelection.length <= textLen) {
    _textView.selectedRange = savedSelection;
  }

  _isApplyingFormatting = NO;

  [self updateEmptyBulletMarker];
}

- (void)applyWritingDirection
{
  NSTextStorage *textStorage = _textView.textStorage;
  if (textStorage.length == 0) {
    return;
  }
  [textStorage beginEditing];
  ENRMApplyWritingDirectionMode(textStorage, _writingDirectionMode, _resolvedLayoutDirection);
  [textStorage endEditing];
}

#pragma mark - Commands

- (void)focus
{
  ENRMFocusTextView(_textView);
}

- (void)blur
{
  ENRMBlurTextView(_textView);
}

- (void)setValue:(NSString *)markdown
{
  [self importMarkdown:markdown];
  _lastSelectedRange = _textView.selectedRange;
  [self emitOnChangeText];
  [self emitOnChangeSelection];
  [self emitOnChangeState];
  [self requestHeightUpdate];
}

- (void)setSelection:(NSInteger)start end:(NSInteger)end
{
  NSInteger textLen = (NSInteger)ENRMGetPlainText(_textView).length;
  NSInteger clampedStart = MIN(MAX(start, 0), textLen);
  NSInteger clampedEnd = MIN(MAX(end, clampedStart), textLen);
  _textView.selectedRange = NSMakeRange((NSUInteger)clampedStart, (NSUInteger)(clampedEnd - clampedStart));
  [self emitOnChangeSelection];
  [self emitOnChangeState];
}

- (void)toggleBold
{
  [self toggleInlineStyle:ENRMInputStyleTypeStrong];
}

- (void)toggleItalic
{
  [self toggleInlineStyle:ENRMInputStyleTypeEmphasis];
}

- (void)toggleUnderline
{
  [self toggleInlineStyle:ENRMInputStyleTypeUnderline];
}

- (void)toggleStrikethrough
{
  [self toggleInlineStyle:ENRMInputStyleTypeStrikethrough];
}

- (void)toggleSpoiler
{
  [self toggleInlineStyle:ENRMInputStyleTypeSpoiler];
}

#pragma mark - Block styles

/// Block type stored on the cursor's line. Falls back to the pending kind for an
/// empty line (no character holds the attribute yet).
- (ENRMInputBlockType)blockTypeForCursorParagraph
{
  NSTextStorage *storage = _textView.textStorage;
  NSString *text = storage.string;
  if (text.length == 0) {
    return _pendingBlockType;
  }
  NSRange paragraphRange = [text paragraphRangeForRange:_textView.selectedRange];
  NSUInteger probe = paragraphRange.location;
  if (probe >= text.length || [text characterAtIndex:probe] == '\n') {
    return _pendingBlockType;
  }
  id value = [storage attribute:ENRMBlockTypeAttributeName atIndex:probe effectiveRange:NULL];
  return value ? (ENRMInputBlockType)[value integerValue] : ENRMInputBlockTypeParagraph;
}

/// List depth of the cursor's line, or the pending depth for an empty line.
- (NSInteger)listDepthForCursorParagraph
{
  NSTextStorage *storage = _textView.textStorage;
  NSString *text = storage.string;
  if (text.length == 0) {
    return _pendingListDepth;
  }
  NSRange paragraphRange = [text paragraphRangeForRange:_textView.selectedRange];
  NSUInteger probe = paragraphRange.location;
  if (probe >= text.length || [text characterAtIndex:probe] == '\n') {
    return _pendingListDepth;
  }
  id value = [storage attribute:ENRMListDepthAttributeName atIndex:probe effectiveRange:NULL];
  return value ? [value integerValue] : 0;
}

- (void)toggleUnorderedList
{
  BOOL turningOff = ([self blockTypeForCursorParagraph] == ENRMInputBlockTypeUnorderedListItem);
  ENRMInputBlockType newType = turningOff ? ENRMInputBlockTypeParagraph : ENRMInputBlockTypeUnorderedListItem;

  NSTextStorage *storage = _textView.textStorage;
  NSString *text = storage.string;

  if (text.length > 0) {
    NSRange paragraphRange = [text paragraphRangeForRange:_textView.selectedRange];
    [storage beginEditing];
    [text enumerateSubstringsInRange:paragraphRange
                             options:NSStringEnumerationByLines
                          usingBlock:^(NSString *line, NSRange lineRange, NSRange enclosingRange, BOOL *stop) {
                            if (lineRange.length == 0) {
                              return;
                            }
                            if (newType == ENRMInputBlockTypeParagraph) {
                              [storage removeAttribute:ENRMBlockTypeAttributeName range:lineRange];
                              [storage removeAttribute:ENRMListDepthAttributeName range:lineRange];
                            } else {
                              [storage addAttribute:ENRMBlockTypeAttributeName
                                              value:@(ENRMInputBlockTypeUnorderedListItem)
                                              range:lineRange];
                              [storage addAttribute:ENRMListDepthAttributeName value:@(0) range:lineRange];
                            }
                          }];
    [storage endEditing];
  }

  _pendingBlockType = newType;
  _pendingListDepth = 0;
  _keepPendingBlockOnEmptyLine = (newType == ENRMInputBlockTypeUnorderedListItem);

  [self applyFormatting];
  [self syncTypingAttributesWithPendingStyles];
  [self emitFormattingChanged];
}

- (void)indentList
{
  [self changeListDepthBy:1];
}

- (void)outdentList
{
  [self changeListDepthBy:-1];
}

/// Adjusts the nesting depth of every list line the selection touches, clamped
/// to [0, ENRMMaxListDepth]. No-op on non-list lines.
- (void)changeListDepthBy:(NSInteger)delta
{
  if ([self blockTypeForCursorParagraph] != ENRMInputBlockTypeUnorderedListItem) {
    return;
  }
  NSTextStorage *storage = _textView.textStorage;
  NSString *text = storage.string;
  if (text.length == 0) {
    _pendingListDepth = MIN(MAX(_pendingListDepth + delta, (NSInteger)0), ENRMMaxListDepth);
    _keepPendingBlockOnEmptyLine = YES;
    [self emitFormattingChanged];
    return;
  }

  NSRange paragraphRange = [text paragraphRangeForRange:_textView.selectedRange];
  [storage beginEditing];
  [text enumerateSubstringsInRange:paragraphRange
                           options:NSStringEnumerationByLines
                        usingBlock:^(NSString *line, NSRange lineRange, NSRange enclosingRange, BOOL *stop) {
                          if (lineRange.length == 0) {
                            return;
                          }
                          id type = [storage attribute:ENRMBlockTypeAttributeName
                                               atIndex:lineRange.location
                                        effectiveRange:NULL];
                          if (!type || [type integerValue] != ENRMInputBlockTypeUnorderedListItem) {
                            return;
                          }
                          id depthValue = [storage attribute:ENRMListDepthAttributeName
                                                     atIndex:lineRange.location
                                              effectiveRange:NULL];
                          NSInteger depth = depthValue ? [depthValue integerValue] : 0;
                          NSInteger newDepth = MIN(MAX(depth + delta, (NSInteger)0), ENRMMaxListDepth);
                          [storage addAttribute:ENRMListDepthAttributeName value:@(newDepth) range:lineRange];
                        }];
  [storage endEditing];

  _pendingListDepth = MIN(MAX([self listDepthForCursorParagraph] + delta, (NSInteger)0), ENRMMaxListDepth);

  [self applyFormatting];
  [self syncTypingAttributesWithPendingStyles];
  [self emitFormattingChanged];
}

/// Writes parsed list ranges into the text storage as block attributes. Caller
/// owns the surrounding `_isApplyingFormatting` guard.
- (void)applyBlockRanges:(NSArray<ENRMBlockRange *> *)blockRanges
{
  NSTextStorage *storage = _textView.textStorage;
  NSUInteger length = storage.length;
  if (length == 0) {
    return;
  }
  NSRange fullRange = NSMakeRange(0, length);
  [storage beginEditing];
  [storage removeAttribute:ENRMBlockTypeAttributeName range:fullRange];
  [storage removeAttribute:ENRMListDepthAttributeName range:fullRange];
  for (ENRMBlockRange *blockRange in blockRanges) {
    if (blockRange.type != ENRMInputBlockTypeUnorderedListItem) {
      continue;
    }
    NSRange range = NSIntersectionRange(blockRange.range, fullRange);
    if (range.length == 0) {
      continue;
    }
    [storage addAttribute:ENRMBlockTypeAttributeName value:@(blockRange.type) range:range];
    [storage addAttribute:ENRMListDepthAttributeName value:@(blockRange.depth) range:range];
  }
  [storage endEditing];
}

/// Block (list) ranges currently stored as text attributes, in text-storage
/// coordinates. Source of truth for serialization and state queries.
- (NSArray<ENRMBlockRange *> *)currentBlockRanges
{
  NSTextStorage *storage = _textView.textStorage;
  NSUInteger length = storage.length;
  if (length == 0) {
    return @[];
  }
  NSMutableArray<ENRMBlockRange *> *result = [NSMutableArray array];
  [storage enumerateAttribute:ENRMBlockTypeAttributeName
                      inRange:NSMakeRange(0, length)
                      options:0
                   usingBlock:^(id value, NSRange range, BOOL *stop) {
                     if (!value || [value integerValue] != ENRMInputBlockTypeUnorderedListItem) {
                       return;
                     }
                     NSNumber *depthValue = [storage attribute:ENRMListDepthAttributeName
                                                       atIndex:range.location
                                                effectiveRange:NULL];
                     [result addObject:[ENRMBlockRange rangeWithType:ENRMInputBlockTypeUnorderedListItem
                                                               depth:depthValue ? depthValue.integerValue : 0
                                                               range:range]];
                   }];
  return result;
}

- (void)toggleInlineStyle:(ENRMInputStyleType)styleType
{
  id<ENRMStyleHandler> handler = [_formatter handlerForStyleType:styleType];
  if (!handler) {
    return;
  }
  ENRMStyleMergingConfig *mergingConfig = handler.mergingConfig;

  NSRange selection = _textView.selectedRange;
  NSUInteger cursor = selection.location;
  NSNumber *key = @(styleType);

  // Check blocking rules: if any blocking style is active, refuse to toggle on.
  if (mergingConfig.blockingStyles.count > 0) {
    BOOL isCurrentlyActive = [_formattingStore isStyleActive:styleType atPosition:cursor];
    if (!isCurrentlyActive) {
      for (NSNumber *blockerNum in mergingConfig.blockingStyles) {
        if ([_formattingStore isStyleActive:(ENRMInputStyleType)blockerNum.integerValue atPosition:cursor]) {
          return;
        }
      }
    }
  }

  if (selection.length > 0) {
    BOOL fullyStyled = YES;
    NSUInteger pos = selection.location;
    NSUInteger selEnd = NSMaxRange(selection);
    while (pos < selEnd) {
      ENRMFormattingRange *match = [_formattingStore rangeOfType:styleType containingPosition:pos];
      if (match == nil) {
        fullyStyled = NO;
        break;
      }
      pos = NSMaxRange(match.range);
    }
    if (fullyStyled) {
      [_formattingStore removeType:styleType inRange:selection];
    } else {
      // Remove conflicting styles from the range before applying.
      for (NSNumber *conflictNum in mergingConfig.conflictingStyles) {
        [_formattingStore removeType:(ENRMInputStyleType)conflictNum.integerValue inRange:selection];
      }
      ENRMFormattingRange *newRange = [ENRMFormattingRange rangeWithType:styleType range:selection];
      [_formattingStore addRange:newRange];
    }
    [_pendingStyles removeObject:key];
    [_pendingStyleRemovals removeObject:key];
  } else {
    BOOL isInsideRange = [_formattingStore isStyleActive:styleType atPosition:cursor];

    if ([_pendingStyleRemovals containsObject:key]) {
      [_pendingStyleRemovals removeObject:key];
    } else if ([_pendingStyles containsObject:key]) {
      [_pendingStyles removeObject:key];
    } else if (isInsideRange) {
      [_pendingStyleRemovals addObject:key];
    } else {
      [_pendingStyles addObject:key];
    }
  }

  [self applyFormatting];
  [self syncTypingAttributesWithPendingStyles];
  [self emitFormattingChanged];
}

- (void)setLink:(NSString *)url
{
  NSRange selection = _textView.selectedRange;
  NSUInteger cursor = selection.location;

  ENRMFormattingRange *activeLink = [_formattingStore rangeOfType:ENRMInputStyleTypeLink containingPosition:cursor];

  if (activeLink != nil) {
    activeLink.url = url;
    [_autoLinkDetector clearAutoLinkInRange:activeLink.range];
  } else if (selection.length > 0) {
    ENRMFormattingRange *linkRange = [ENRMFormattingRange rangeWithType:ENRMInputStyleTypeLink range:selection url:url];
    [_formattingStore addRange:linkRange];
    [_autoLinkDetector clearAutoLinkInRange:selection];
  } else {
    return;
  }

  [self applyFormatting];
  [self emitFormattingChanged];
}

- (void)insertLink:(NSString *)text url:(NSString *)url
{
  NSString *displayText = text.length > 0 ? text : url;
  NSRange linkRange = NSMakeRange(0, displayText.length);
  ENRMFormattingRange *range = [ENRMFormattingRange rangeWithType:ENRMInputStyleTypeLink
                                                            range:linkRange
                                                              url:[self sanitizeLinkURL:url]];
  [self replaceSelectedTextWith:displayText formattingRanges:@[ range ]];
}

- (NSString *)sanitizeLinkURL:(NSString *)url
{
  NSString *result = [url stringByReplacingOccurrencesOfString:@"(" withString:@"%28"];
  return [result stringByReplacingOccurrencesOfString:@")" withString:@"%29"];
}

- (void)startMention:(NSString *)indicator
{
  if (indicator.length == 0 || ![_mentionIndicators containsObject:indicator]) {
    return;
  }

  [self replaceSelectedTextWith:indicator formattingRanges:@[]];
  [self updateActiveMention];
}

- (void)insertMention:(NSString *)displayText url:(NSString *)url
{
  if (displayText.length == 0 || _activeMentionIndicator == nil || _activeMentionRange.location == NSNotFound) {
    return;
  }

  NSString *plainText = ENRMGetPlainText(_textView);
  NSUInteger rangeEnd = NSMaxRange(_activeMentionRange);
  if (rangeEnd > plainText.length) {
    return;
  }
  BOOL nextCharIsWhitespace = rangeEnd < plainText.length && [[NSCharacterSet whitespaceAndNewlineCharacterSet]
                                                                 characterIsMember:[plainText
                                                                                       characterAtIndex:rangeEnd]];
  NSString *replacement = nextCharIsWhitespace ? displayText : [displayText stringByAppendingString:@" "];
  ENRMFormattingRange *linkRange = [ENRMFormattingRange rangeWithType:ENRMInputStyleTypeLink
                                                                range:NSMakeRange(0, displayText.length)
                                                                  url:[self sanitizeLinkURL:url]];
  NSString *indicator = _activeMentionIndicator;
  NSRange mentionRange = _activeMentionRange;

  [self clearActiveMention:indicator];
  [self replaceTextInRange:mentionRange withText:replacement formattingRanges:@[ linkRange ]];
  _textView.selectedRange = NSMakeRange(mentionRange.location + replacement.length, 0);
  [self emitOnChangeSelection];
}

- (void)removeLink
{
  NSUInteger cursor = _textView.selectedRange.location;
  ENRMFormattingRange *activeLink = [_formattingStore rangeOfType:ENRMInputStyleTypeLink containingPosition:cursor];
  if (activeLink == nil) {
    return;
  }

  [_formattingStore removeRange:activeLink];
  [self applyFormatting];
  [self emitFormattingChanged];
}

- (void)showLinkPrompt
{
  NSUInteger cursor = _textView.selectedRange.location;
  ENRMFormattingRange *activeLink = [_formattingStore rangeOfType:ENRMInputStyleTypeLink containingPosition:cursor];
  NSString *existingURL = activeLink != nil ? activeLink.url : nil;

  __weak EnrichedMarkdownTextInput *weakSelf = self;
  ENRMShowLinkPrompt(self, existingURL, ^(NSString *url) { [weakSelf setLink:url]; });
}

- (nullable NSString *)markdownForSelectedRange
{
  NSRange selection = _textView.selectedRange;
  if (selection.length == 0) {
    return nil;
  }

  NSString *fullText = ENRMGetPlainText(_textView);
  NSString *selectedText = [fullText substringWithRange:selection];
  NSUInteger selEnd = NSMaxRange(selection);

  NSMutableArray<ENRMFormattingRange *> *clippedRanges = [NSMutableArray array];
  for (ENRMFormattingRange *range in [self allRangesIncludingTransient]) {
    NSUInteger rangeStart = range.range.location;
    NSUInteger rangeEnd = NSMaxRange(range.range);

    if (rangeEnd <= selection.location || rangeStart >= selEnd) {
      continue;
    }

    NSUInteger clippedStart = MAX(rangeStart, selection.location);
    NSUInteger clippedEnd = MIN(rangeEnd, selEnd);
    NSRange shifted = NSMakeRange(clippedStart - selection.location, clippedEnd - clippedStart);

    [clippedRanges addObject:[ENRMFormattingRange rangeWithType:range.type range:shifted url:range.url]];
  }

  return [ENRMMarkdownSerializer serializePlainText:selectedText ranges:clippedRanges];
}

- (void)requestMarkdown:(NSInteger)requestId
{
  auto emitter = [self getEventEmitter];
  if (emitter == nullptr) {
    return;
  }
  NSString *markdown = [ENRMMarkdownSerializer serializePlainText:ENRMGetPlainText(_textView)
                                                           ranges:[self allRangesIncludingTransient]
                                                      blockRanges:[self currentBlockRanges]];
  emitter->onRequestMarkdownResult({
      .requestId = static_cast<int>(requestId),
      .markdown = std::string([markdown UTF8String] ?: ""),
  });
}

- (CGRect)computeCaretRect
{
  CGRect caretRect = CGRectZero;
#if !TARGET_OS_OSX
  UITextRange *selectedRange = _textView.selectedTextRange;
  if (selectedRange != nil) {
    caretRect = [_textView caretRectForPosition:selectedRange.start];
  }
#else
  NSRange selection = _textView.selectedRange;
  if (selection.location != NSNotFound) {
    NSRange glyphRange = [_textView.layoutManager glyphRangeForCharacterRange:NSMakeRange(selection.location, 0)
                                                         actualCharacterRange:NULL];
    caretRect = [_textView.layoutManager boundingRectForGlyphRange:glyphRange inTextContainer:_textView.textContainer];
    caretRect.origin.x += _textView.textContainerInset.left;
    caretRect.origin.y += _textView.textContainerInset.top;
  }
#endif
  return caretRect;
}

- (void)requestCaretRect:(NSInteger)requestId
{
  auto emitter = [self getEventEmitter];
  if (emitter == nullptr) {
    return;
  }

  CGRect caretRect = [self computeCaretRect];
  emitter->onRequestCaretRectResult({
      .requestId = static_cast<int>(requestId),
      .x = caretRect.origin.x,
      .y = caretRect.origin.y,
      .width = caretRect.size.width,
      .height = caretRect.size.height,
  });
}

- (void)handleCommand:(const NSString *)commandName args:(const NSArray *)args
{
  RCTEnrichedMarkdownTextInputHandleCommand(self, commandName, args);
}

#pragma mark - Style state query

- (BOOL)isEffectiveStyleActive:(ENRMInputStyleType)type atPosition:(NSUInteger)position
{
  BOOL inRange = [_formattingStore isStyleActive:type atPosition:position];
  NSNumber *key = @(type);
  if ([_pendingStyleRemovals containsObject:key]) {
    return NO;
  }
  if ([_pendingStyles containsObject:key]) {
    return YES;
  }
  return inRange;
}

- (void)syncTypingAttributesWithPendingStyles
{
  UIFontDescriptorSymbolicTraits traits = 0;
  if ([_pendingStyles containsObject:@(ENRMInputStyleTypeStrong)]) {
    traits |= UIFontDescriptorTraitBold;
  }
  if ([_pendingStyles containsObject:@(ENRMInputStyleTypeEmphasis)]) {
    traits |= UIFontDescriptorTraitItalic;
  }

  NSMutableDictionary *attrs = [_textView.typingAttributes mutableCopy];
  attrs[NSFontAttributeName] = [_formatterStyle fontForTraits:traits];

  // Carry the list block attribute so the next character continues the list line.
  if ([self blockTypeForCursorParagraph] == ENRMInputBlockTypeUnorderedListItem) {
    NSInteger depth = [self listDepthForCursorParagraph];
    attrs[ENRMBlockTypeAttributeName] = @(ENRMInputBlockTypeUnorderedListItem);
    attrs[ENRMListDepthAttributeName] = @(depth);
    // Indent the caret on an empty list line so it (and its bullet) align with a
    // typed item.
    NSMutableParagraphStyle *paragraph = [[NSMutableParagraphStyle alloc] init];
    CGFloat indent = depth * ENRMListIndentPerDepth + ENRMListMarkerWidth;
    paragraph.firstLineHeadIndent = indent;
    paragraph.headIndent = indent;
    // Gap goes ABOVE each item (paragraphSpacingBefore), not below, so it's
    // present on the empty line immediately without inflating the empty
    // paragraph's caret (which would make the caret shrink on the first keystroke).
    paragraph.paragraphSpacingBefore = _formatterStyle.listItemSpacing;
    attrs[NSParagraphStyleAttributeName] = paragraph;
  } else {
    [attrs removeObjectForKey:ENRMBlockTypeAttributeName];
    [attrs removeObjectForKey:ENRMListDepthAttributeName];
    [attrs removeObjectForKey:NSParagraphStyleAttributeName];
  }
  _textView.typingAttributes = attrs;
}

/// Tells the layout manager to draw a bullet on the cursor's empty list line (it
/// has no character to anchor the marker to). Cleared whenever the cursor isn't
/// on an empty list line.
- (void)updateEmptyBulletMarker
{
  NSString *text = ENRMGetPlainText(_textView);
  NSRange selection = _textView.selectedRange;
  BOOL show = NO;
  NSUInteger location = 0;
  NSInteger depth = 0;

  if (selection.length == 0 && [self blockTypeForCursorParagraph] == ENRMInputBlockTypeUnorderedListItem) {
    NSRange paragraphRange = text.length == 0 ? NSMakeRange(0, 0) : [text paragraphRangeForRange:selection];
    NSString *paragraphText = text.length == 0 ? @"" : [text substringWithRange:paragraphRange];
    BOOL empty = paragraphText.length == 0 || [paragraphText isEqualToString:@"\n"];
    if (empty) {
      show = YES;
      location = paragraphRange.location;
      depth = [self listDepthForCursorParagraph];

      // A mid-document empty list line is just a newline with no paragraph style,
      // so it lays out flush left — the caret stays un-indented and the marker is
      // drawn off the left edge (clipped). Stamp the list paragraph style onto the
      // line so it indents and the bullet positions correctly, immediately, before
      // any character is typed. (The trailing empty line uses the extra line
      // fragment, which is why only the last line worked before.)
      if (paragraphRange.length > 0) {
        NSMutableParagraphStyle *paragraph = [[NSMutableParagraphStyle alloc] init];
        CGFloat indent = depth * ENRMListIndentPerDepth + ENRMListMarkerWidth;
        paragraph.firstLineHeadIndent = indent;
        paragraph.headIndent = indent;
        paragraph.paragraphSpacingBefore = _formatterStyle.listItemSpacing;
        NSTextStorage *storage = _textView.textStorage;
        [storage beginEditing];
        [storage addAttribute:NSParagraphStyleAttributeName value:paragraph range:paragraphRange];
        [storage endEditing];
      }
    }
  }

  _layoutManager.emptyBulletDepth = show ? depth : -1;
  _layoutManager.emptyBulletLocation = location;
  _layoutManager.emptyBulletFont = _formatterStyle.baseFont;
  _layoutManager.emptyBulletColor = _formatterStyle.baseTextColor;
  _layoutManager.listItemSpacing = _formatterStyle.listItemSpacing;

  // An empty editor never runs the formatter (it early-returns at length 0), so
  // the trailing/extra line fragment the marker draws into isn't laid out yet —
  // force it so the bullet appears before the first keystroke.
  if (show && text.length == 0) {
    [_layoutManager ensureLayoutForTextContainer:_textView.textContainer];
  }
  ENRMSetNeedsDisplay(_textView);

  // The empty-editor bullet would otherwise overlap the placeholder.
  [self updatePlaceholderVisibility];
}

- (void)resetPendingStylesForSelectionChange
{
  // Skip system-driven selection adjustments (e.g., predictive text) that fire
  // immediately after a text edit.
  static const CFTimeInterval kPostEditGracePeriod = 0.1;
  BOOL isPostEditAdjustment =
      (_lastTextChangeTime > 0 && (CACurrentMediaTime() - _lastTextChangeTime) < kPostEditGracePeriod);
  if (isPostEditAdjustment) {
    return;
  }
  [_pendingStyles removeAllObjects];
  [_pendingStyleRemovals removeAllObjects];
  // List kind carries via the stored attribute on non-empty lines; clear the
  // pending kind so it never leaks onto a different (empty) line — unless a list
  // was just continued/toggled onto this still-empty line, where the pending kind
  // is the only thing keeping the marker alive until the first character.
  if (_keepPendingBlockOnEmptyLine && [self cursorIsOnEmptyLine]) {
    // Keep the pending list kind; the flag persists until a glyph lands or the
    // caret leaves the empty line.
  } else {
    _keepPendingBlockOnEmptyLine = NO;
    _pendingBlockType = ENRMInputBlockTypeParagraph;
    _pendingListDepth = 0;
  }
  [self rebuildPendingStylesFromContext];
  [self syncTypingAttributesWithPendingStyles];
}

/// Whether the caret (no selection) sits on a line with no text content.
- (BOOL)cursorIsOnEmptyLine
{
  if (_textView.selectedRange.length != 0) {
    return NO;
  }
  NSString *text = _textView.textStorage.string;
  if (text.length == 0) {
    return YES;
  }
  NSUInteger loc = MIN(_textView.selectedRange.location, text.length);
  NSRange paragraph = [text paragraphRangeForRange:NSMakeRange(loc, 0)];
  if (paragraph.length == 0) {
    return YES;
  }
  return [[text substringWithRange:paragraph] isEqualToString:@"\n"];
}

- (void)rebuildPendingStylesFromContext
{
  NSUInteger cursor = _textView.selectedRange.location;
  if (_textView.selectedRange.length > 0 || cursor == 0) {
    return;
  }

  static const ENRMInputStyleType inlineStyles[] = {
      ENRMInputStyleTypeStrong,        ENRMInputStyleTypeEmphasis, ENRMInputStyleTypeUnderline,
      ENRMInputStyleTypeStrikethrough, ENRMInputStyleTypeSpoiler,
  };

  for (NSUInteger i = 0; i < sizeof(inlineStyles) / sizeof(inlineStyles[0]); i++) {
    ENRMInputStyleType type = inlineStyles[i];
    if ([_formattingStore isStyleAdjacentBefore:type position:cursor]) {
      [_pendingStyles addObject:@(type)];
    }
  }
}

#pragma mark - Event emitters

- (void)emitFormattingChanged
{
  [self emitOnChangeState];
  if (_emitMarkdown) {
    [self emitOnChangeMarkdown];
  }
}

- (std::shared_ptr<EnrichedMarkdownTextInputEventEmitter const>)getEventEmitter
{
  if (_eventEmitter == nullptr || _blockEmitting) {
    return nullptr;
  }
  return std::static_pointer_cast<EnrichedMarkdownTextInputEventEmitter const>(_eventEmitter);
}

- (NSArray<ENRMFormattingRange *> *)allRangesIncludingTransient
{
  NSArray<ENRMFormattingRange *> *transient = [_detectorPipeline allTransientFormattingRanges];
  if (transient.count == 0) {
    return _formattingStore.allRanges;
  }
  NSMutableArray<ENRMFormattingRange *> *merged = [_formattingStore.allRanges mutableCopy];
  [merged addObjectsFromArray:transient];
  return merged;
}

- (void)clearActiveMention:(nullable NSString *)indicatorOverride
{
  NSString *indicator = indicatorOverride ?: _activeMentionIndicator;
  _activeMentionIndicator = nil;
  _activeMentionRange = NSMakeRange(NSNotFound, 0);
  _activeMentionText = @"";

  if (indicator.length > 0) {
    [self emitOnEndMention:indicator];
  }
}

- (nullable ENRMInputMentionCandidate *)mentionCandidateAtCursor
{
  NSRange selectedRange = _textView.selectedRange;
  if (_mentionIndicators.count == 0 || selectedRange.length != 0) {
    return nil;
  }

  NSString *plainText = ENRMGetPlainText(_textView);
  NSUInteger cursor = selectedRange.location;
  if (cursor > plainText.length) {
    return nil;
  }

  NSUInteger start = [ENRMWordsUtils tokenStartInText:plainText beforePosition:cursor];
  NSString *token = [plainText substringWithRange:NSMakeRange(start, cursor - start)];
  NSString *matchedIndicator = nil;
  for (NSString *indicator in _mentionIndicators) {
    if ([token hasPrefix:indicator]) {
      matchedIndicator = indicator;
      break;
    }
  }
  if (matchedIndicator == nil) {
    return nil;
  }

  if ([_formattingStore rangeOfType:ENRMInputStyleTypeLink containingPosition:start] != nil) {
    return nil;
  }

  return [ENRMInputMentionCandidate candidateWithIndicator:matchedIndicator
                                                     start:start
                                                       end:cursor
                                                      text:[token substringFromIndex:matchedIndicator.length]];
}

- (void)updateActiveMention
{
  ENRMInputMentionCandidate *candidate = [self mentionCandidateAtCursor];
  if (candidate == nil) {
    [self clearActiveMention:nil];
    return;
  }

  NSString *indicator = candidate.indicator;
  NSUInteger start = candidate.start;
  NSUInteger end = candidate.end;
  NSString *query = candidate.text;

  if (_activeMentionIndicator == nil || ![_activeMentionIndicator isEqualToString:indicator] ||
      _activeMentionRange.location != start) {
    if (_activeMentionIndicator != nil) {
      [self emitOnEndMention:_activeMentionIndicator];
    }
    _activeMentionIndicator = indicator;
    [self emitOnStartMention:indicator];
  }
  _activeMentionRange = NSMakeRange(start, end - start);

  if (![_activeMentionText isEqualToString:query]) {
    _activeMentionText = query;
    [self emitOnChangeMentionWithIndicator:indicator text:query];
  }
}

- (BOOL)deleteLinkForReplacementRange:(NSRange)range replacementText:(NSString *)text
{
  if (text.length > 0) {
    return NO;
  }

  NSUInteger lookupPosition;
  if (range.length > 0) {
    lookupPosition = range.location;
  } else if (range.location > 0) {
    lookupPosition = range.location - 1;
  } else {
    return NO;
  }

  ENRMFormattingRange *linkRange = [_formattingStore rangeOfType:ENRMInputStyleTypeLink
                                              containingPosition:lookupPosition];
  if (linkRange == nil) {
    return NO;
  }

  [self replaceTextInRange:linkRange.range withText:@"" formattingRanges:@[]];
  [self clearActiveMention:nil];
  return YES;
}

- (void)emitOnChangeText
{
  auto emitter = [self getEventEmitter];
  if (emitter == nullptr) {
    return;
  }
  NSString *plainText = ENRMGetPlainText(_textView);
  emitter->onChangeText({.value = std::string([plainText UTF8String] ?: "")});
}

- (void)emitOnChangeMarkdown
{
  auto emitter = [self getEventEmitter];
  if (emitter == nullptr) {
    return;
  }
  NSString *markdown = [ENRMMarkdownSerializer serializePlainText:ENRMGetPlainText(_textView)
                                                           ranges:[self allRangesIncludingTransient]
                                                      blockRanges:[self currentBlockRanges]];
  emitter->onChangeMarkdown({.value = std::string([markdown UTF8String] ?: "")});
}

- (void)emitOnChangeSelection
{
  auto emitter = [self getEventEmitter];
  if (emitter == nullptr) {
    return;
  }
  NSRange selection = _textView.selectedRange;
  emitter->onChangeSelection({
      .start = static_cast<int>(selection.location),
      .end = static_cast<int>(NSMaxRange(selection)),
  });
}

- (void)emitOnChangeState
{
  auto emitter = [self getEventEmitter];
  if (emitter == nullptr) {
    return;
  }

  NSUInteger cursor = _textView.selectedRange.location;
  BOOL boldActive = [self isEffectiveStyleActive:ENRMInputStyleTypeStrong atPosition:cursor];
  BOOL italicActive = [self isEffectiveStyleActive:ENRMInputStyleTypeEmphasis atPosition:cursor];
  BOOL underlineActive = [self isEffectiveStyleActive:ENRMInputStyleTypeUnderline atPosition:cursor];
  BOOL strikethroughActive = [self isEffectiveStyleActive:ENRMInputStyleTypeStrikethrough atPosition:cursor];
  BOOL spoilerActive = [self isEffectiveStyleActive:ENRMInputStyleTypeSpoiler atPosition:cursor];
  BOOL linkActive = [self isEffectiveStyleActive:ENRMInputStyleTypeLink atPosition:cursor];
  BOOL unorderedListActive = [self blockTypeForCursorParagraph] == ENRMInputBlockTypeUnorderedListItem;

  if (_prevState.initialized && _prevState.bold == boldActive && _prevState.italic == italicActive &&
      _prevState.underline == underlineActive && _prevState.strikethrough == strikethroughActive &&
      _prevState.spoiler == spoilerActive && _prevState.link == linkActive &&
      _prevState.unorderedList == unorderedListActive) {
    return;
  }

  _prevState.bold = boldActive;
  _prevState.italic = italicActive;
  _prevState.underline = underlineActive;
  _prevState.strikethrough = strikethroughActive;
  _prevState.spoiler = spoilerActive;
  _prevState.link = linkActive;
  _prevState.unorderedList = unorderedListActive;
  _prevState.initialized = YES;

  emitter->onChangeState({
      .bold = {.isActive = boldActive},
      .italic = {.isActive = italicActive},
      .underline = {.isActive = underlineActive},
      .strikethrough = {.isActive = strikethroughActive},
      .spoiler = {.isActive = spoilerActive},
      .link = {.isActive = linkActive},
      .unorderedList = {.isActive = unorderedListActive},
  });
}

- (void)emitCaretRectChangeIfNeeded
{
  auto emitter = [self getEventEmitter];
  if (emitter == nullptr) {
    return;
  }

  CGRect caretRect = [self computeCaretRect];

  if (_prevCaretRect.has_value() && CGRectEqualToRect(_prevCaretRect.value(), caretRect)) {
    return;
  }

  _prevCaretRect = caretRect;

  emitter->onCaretRectChange({
      .x = caretRect.origin.x,
      .y = caretRect.origin.y,
      .width = caretRect.size.width,
      .height = caretRect.size.height,
  });
}

- (NSArray<NSString *> *)contextMenuItemTexts
{
  return _contextMenuItemTexts ?: @[];
}

- (NSArray<NSString *> *)contextMenuItemIcons
{
  return _contextMenuItemIcons ?: @[];
}

- (ENRMInputSelectionMenuConfig)inputSelectionMenuConfig
{
  return _inputSelectionMenuConfig;
}

- (ENRMFormatMenuConfig)formatMenuConfig
{
  return _formatMenuConfig;
}

- (void)emitContextMenuItemPress:(NSString *)itemText
{
  auto eventEmitter = [self getEventEmitter];
  if (eventEmitter == nullptr) {
    return;
  }

  NSRange selectedRange = _textView.selectedRange;
  NSString *selectedText =
      selectedRange.length > 0 ? [_textView.textStorage.string substringWithRange:selectedRange] : @"";

  auto isActive = [&](ENRMInputStyleType type) -> BOOL {
    if (selectedRange.length > 0) {
      return [_formattingStore isStyleActive:type inRange:selectedRange];
    }
    return [self isEffectiveStyleActive:type atPosition:selectedRange.location];
  };

  BOOL boldActive = isActive(ENRMInputStyleTypeStrong);
  BOOL italicActive = isActive(ENRMInputStyleTypeEmphasis);
  BOOL underlineActive = isActive(ENRMInputStyleTypeUnderline);
  BOOL strikethroughActive = isActive(ENRMInputStyleTypeStrikethrough);
  BOOL spoilerActive = isActive(ENRMInputStyleTypeSpoiler);
  BOOL linkActive = isActive(ENRMInputStyleTypeLink);
  BOOL unorderedListActive = [self blockTypeForCursorParagraph] == ENRMInputBlockTypeUnorderedListItem;

  eventEmitter->onContextMenuItemPress({
      .itemText = std::string(itemText.UTF8String),
      .selectedText = std::string(selectedText.UTF8String),
      .selectionStart = static_cast<int>(selectedRange.location),
      .selectionEnd = static_cast<int>(NSMaxRange(selectedRange)),
      .styleState =
          {
              .bold = {.isActive = boldActive},
              .italic = {.isActive = italicActive},
              .underline = {.isActive = underlineActive},
              .strikethrough = {.isActive = strikethroughActive},
              .spoiler = {.isActive = spoilerActive},
              .link = {.isActive = linkActive},
              .unorderedList = {.isActive = unorderedListActive},
          },
  });
}

- (void)emitOnFocus
{
  auto emitter = [self getEventEmitter];
  if (emitter == nullptr) {
    return;
  }
  emitter->onInputFocus({});
}

- (void)emitOnBlur
{
  auto emitter = [self getEventEmitter];
  if (emitter == nullptr) {
    return;
  }
  emitter->onInputBlur({});
}

- (void)emitOnLinkDetectedWithText:(NSString *)text url:(NSString *)url range:(NSRange)range
{
  auto emitter = [self getEventEmitter];
  if (emitter == nullptr) {
    return;
  }
  emitter->onLinkDetected({
      .text = std::string([text UTF8String] ?: ""),
      .url = std::string([url UTF8String] ?: ""),
      .start = static_cast<int>(range.location),
      .end = static_cast<int>(range.location + range.length),
  });
}

- (void)emitOnStartMention:(NSString *)indicator
{
  auto emitter = [self getEventEmitter];
  if (emitter == nullptr) {
    return;
  }
  emitter->onStartMention({.indicator = std::string([indicator UTF8String] ?: "")});
}

- (void)emitOnChangeMentionWithIndicator:(NSString *)indicator text:(NSString *)text
{
  auto emitter = [self getEventEmitter];
  if (emitter == nullptr) {
    return;
  }
  emitter->onChangeMention({
      .indicator = std::string([indicator UTF8String] ?: ""),
      .text = std::string([text UTF8String] ?: ""),
  });
}

- (void)emitOnEndMention:(NSString *)indicator
{
  auto emitter = [self getEventEmitter];
  if (emitter == nullptr) {
    return;
  }
  emitter->onEndMention({.indicator = std::string([indicator UTF8String] ?: "")});
}

#pragma mark - Text edit tracking

- (void)handleTextChanged
{
  if (ENRMHasMarkedText(_textView)) {
    return;
  }

  NSUInteger newLength = ENRMGetPlainText(_textView).length;
  NSRange selection = _textView.selectedRange;

  NSRange preEditSelection = _preEditSelectedRange;
  NSUInteger editLocation = preEditSelection.location;
  NSUInteger deletedLength = 0;
  NSUInteger insertedLength = 0;

  if (newLength >= _lastTextLength) {
    NSUInteger netInserted = newLength - _lastTextLength;
    deletedLength = preEditSelection.length;
    insertedLength = deletedLength + netInserted;
  } else {
    NSUInteger netDeleted = _lastTextLength - newLength;
    if (preEditSelection.length > 0) {
      deletedLength = preEditSelection.length;
      insertedLength = deletedLength > netDeleted ? deletedLength - netDeleted : 0;
    } else {
      deletedLength = netDeleted;
      insertedLength = 0;
      if (selection.location < editLocation) {
        editLocation = selection.location;
      }
    }
  }

  [_formattingStore adjustForEditAtLocation:editLocation deletedLength:deletedLength insertedLength:insertedLength];

  if (insertedLength > 0) {
    NSRange insertedRange = NSMakeRange(editLocation, insertedLength);

    // Skip applying pending styles when the insertion is only line breaks —
    // a phantom range over a bare newline corrupts isStyleActive() at the boundary.
    NSString *plainText = ENRMGetPlainText(_textView);
    NSUInteger insertedEnd = NSMaxRange(insertedRange);
    BOOL insertedHasGlyphContent = NO;
    if (insertedEnd <= plainText.length) {
      NSCharacterSet *newlines = [NSCharacterSet newlineCharacterSet];
      for (NSUInteger i = insertedRange.location; i < insertedEnd; i++) {
        if (![newlines characterIsMember:[plainText characterAtIndex:i]]) {
          insertedHasGlyphContent = YES;
          break;
        }
      }
    }

    if (insertedHasGlyphContent) {
      for (NSNumber *styleNum in _pendingStyles) {
        ENRMFormattingRange *newRange = [ENRMFormattingRange rangeWithType:(ENRMInputStyleType)styleNum.integerValue
                                                                     range:insertedRange];
        [_formattingStore addRange:newRange];
      }

      // Re-stamp the whole edited line with its block attribute. UIKit drops
      // custom attributes from typingAttributes after the first insertion, and
      // autocorrect/paste can replace the attribute-bearing characters entirely —
      // so re-derive the line's kind (surviving attribute, else the kind captured
      // before the edit) and apply it across the full line, healing both.
      NSTextStorage *storage = _textView.textStorage;
      ENRMInputBlockType lineType = [self blockTypeForCursorParagraph];
      NSInteger lineDepth = [self listDepthForCursorParagraph];
      if (lineType == ENRMInputBlockTypeParagraph && _preEditBlockType != ENRMInputBlockTypeParagraph) {
        lineType = _preEditBlockType;
        lineDepth = _preEditListDepth;
      }
      if (lineType != ENRMInputBlockTypeParagraph && storage.length > 0) {
        NSString *plainNow = storage.string;
        NSRange paragraphRange =
            [plainNow paragraphRangeForRange:NSMakeRange(MIN(_textView.selectedRange.location, plainNow.length), 0)];
        NSRange content = paragraphRange;
        if (content.length > 0 && [plainNow characterAtIndex:NSMaxRange(content) - 1] == '\n') {
          content.length -= 1;
        }
        if (content.length > 0) {
          [storage addAttribute:ENRMBlockTypeAttributeName value:@(lineType) range:content];
          if (lineType == ENRMInputBlockTypeUnorderedListItem) {
            [storage addAttribute:ENRMListDepthAttributeName value:@(lineDepth) range:content];
          } else {
            [storage removeAttribute:ENRMListDepthAttributeName range:content];
          }
        }
      }
    }

    // adjustForEditAtLocation may have expanded an existing range to cover
    // the insertion — carve out the inserted portion for removed styles.
    for (NSNumber *styleNum in _pendingStyleRemovals) {
      [_formattingStore removeType:(ENRMInputStyleType)styleNum.integerValue inRange:insertedRange];
    }

    NSTextStorage *storage = _textView.textStorage;
    NSString *fullText = storage.string;

    if (insertedHasGlyphContent) {
      // Continue list styling onto typed glyphs in a list line. UIKit drops
      // custom attributes from typingAttributes after the first insertion, so
      // stamp directly to storage (matching how inline pending styles work).
      if ([self blockTypeForCursorParagraph] == ENRMInputBlockTypeUnorderedListItem) {
        NSInteger depth = [self listDepthForCursorParagraph];
        NSRange clamped = NSIntersectionRange(insertedRange, NSMakeRange(0, storage.length));
        if (clamped.length > 0) {
          [storage addAttribute:ENRMBlockTypeAttributeName value:@(ENRMInputBlockTypeUnorderedListItem) range:clamped];
          [storage addAttribute:ENRMListDepthAttributeName value:@(depth) range:clamped];
        }
      }
    } else {
      // A newline continues the list: the new line becomes a list item at the
      // same depth. Pressing Enter on an empty item exits the list instead.
      NSUInteger scan = editLocation;
      while (scan > 0 && [fullText characterAtIndex:scan - 1] != '\n') {
        scan--;
      }
      NSUInteger prevLineStart = scan;
      NSUInteger prevContentLength = editLocation > prevLineStart ? editLocation - prevLineStart : 0;

      BOOL prevIsList = NO;
      NSInteger prevDepth = 0;
      if (prevContentLength > 0) {
        id type = [storage attribute:ENRMBlockTypeAttributeName atIndex:prevLineStart effectiveRange:NULL];
        prevIsList = type && [type integerValue] == ENRMInputBlockTypeUnorderedListItem;
        if (prevIsList) {
          id depthValue = [storage attribute:ENRMListDepthAttributeName atIndex:prevLineStart effectiveRange:NULL];
          prevDepth = depthValue ? [depthValue integerValue] : 0;
        }
      } else {
        // Empty previous line — recover its kind from the pending state.
        prevIsList = _pendingBlockType == ENRMInputBlockTypeUnorderedListItem;
        prevDepth = _pendingListDepth;
      }

      if (prevIsList && prevContentLength > 0) {
        _pendingBlockType = ENRMInputBlockTypeUnorderedListItem;
        _pendingListDepth = prevDepth;
        _keepPendingBlockOnEmptyLine = YES;
      } else {
        // Exit the list (empty item) or a plain newline.
        _pendingBlockType = ENRMInputBlockTypeParagraph;
        _pendingListDepth = 0;
        _keepPendingBlockOnEmptyLine = NO;
      }
      // The inserted newline must never carry a block attribute itself.
      NSRange clampedInserted = NSIntersectionRange(insertedRange, NSMakeRange(0, storage.length));
      if (clampedInserted.length > 0) {
        [storage removeAttribute:ENRMBlockTypeAttributeName range:clampedInserted];
        [storage removeAttribute:ENRMListDepthAttributeName range:clampedInserted];
      }
      [self syncTypingAttributesWithPendingStyles];
    }
  }

  // Autocorrect/paste replaces existing characters (range.length > 0); the edit
  // model above is keyed off the caret selection and underestimates the inserted
  // span for such replacements, so the block re-stamp can be skipped entirely.
  // Heal the edited line's block attribute directly. A replacement that inserts a
  // newline is a structural change handled above, so skip it here.
  if (_preEditReplacementLength > 0 && !_preEditReplacementHasNewline) {
    [self healCurrentLineBlockAttribute];
  }
  _preEditReplacementLength = 0;
  _preEditReplacementHasNewline = NO;

  // Once a glyph lands the block attribute lives on real text, so the empty-line
  // keep-flag is no longer needed; drop it to avoid leaking onto another line.
  if (![self cursorIsOnEmptyLine]) {
    _keepPendingBlockOnEmptyLine = NO;
  }

  _lastTextLength = newLength;

#if !TARGET_OS_OSX
  if (newLength == 0) {
    [self resetBaseTypingAttributes];
  }
#endif

  [self applyFormatting];

  // Keep the caret's typing attributes aligned with the list line so the next
  // character continues the bullet (UIKit otherwise drops the custom attribute).
  if ([self blockTypeForCursorParagraph] == ENRMInputBlockTypeUnorderedListItem) {
    [self syncTypingAttributesWithPendingStyles];
  }

  NSUInteger clampedEditLocation = MIN(editLocation, newLength);
  NSUInteger clampedInsertedLength = MIN(insertedLength, newLength - clampedEditLocation);
  [_detectorPipeline processTextChange:ENRMGetPlainText(_textView)
                     modificationRange:NSMakeRange(clampedEditLocation, clampedInsertedLength)];

  [self updatePlaceholderVisibility];
  [self emitOnChangeText];
  [self emitOnChangeSelection];
  [self emitFormattingChanged];
  [self updateActiveMention];
  [self emitCaretRectChangeIfNeeded];
  [self requestHeightUpdate];
  [self scheduleRelayoutIfNeeded];
}

#pragma mark - Text view delegate

#if !TARGET_OS_OSX

- (void)stripLinkTypingAttributes
{
  NSMutableDictionary *attrs = [_textView.typingAttributes mutableCopy];
  BOOL changed = NO;

  UIColor *linkColor = _formatterStyle.linkColor;
  UIColor *currentColor = attrs[NSForegroundColorAttributeName];
  if (currentColor != nil && linkColor != nil && [currentColor isEqual:linkColor]) {
    attrs[NSForegroundColorAttributeName] = _formatterStyle.baseTextColor;
    changed = YES;
  }

  if (attrs[NSUnderlineStyleAttributeName] != nil) {
    [attrs removeObjectForKey:NSUnderlineStyleAttributeName];
    changed = YES;
  }

  if (attrs[NSLinkAttributeName] != nil) {
    [attrs removeObjectForKey:NSLinkAttributeName];
    changed = YES;
  }

  if (changed) {
    _textView.typingAttributes = attrs;
  }
}

- (void)manageSelectionBasedChanges
{
  [self stripLinkTypingAttributes];

  if (_textView.selectedRange.length == 0 && !_isTextChanging) {
    NSString *text = ENRMGetPlainText(_textView);
    if (text.length > 0) {
      NSRange paragraphRange = [text paragraphRangeForRange:_textView.selectedRange];
      NSString *paragraphText = [text substringWithRange:paragraphRange];
      BOOL isEmpty = paragraphText.length == 0 || [paragraphText isEqualToString:@"\n"];
      if (isEmpty) {
        if (_pendingBlockType != ENRMInputBlockTypeParagraph) {
          // Keep an empty heading/list line's typing context (font, block
          // attribute, indent) so its marker stays and the next character
          // continues the block.
          [self syncTypingAttributesWithPendingStyles];
        } else {
          NSMutableDictionary *attrs = [NSMutableDictionary dictionary];
          attrs[NSFontAttributeName] = _formatterStyle.baseFont;
          attrs[NSForegroundColorAttributeName] = _formatterStyle.baseTextColor;
          _textView.typingAttributes = attrs;
        }
      }
    }
  }
}

- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text
{
  if ([self deleteLinkForReplacementRange:range replacementText:text]) {
    return NO;
  }
  if ([self handleListKeyForReplacementRange:range replacementText:text]) {
    return NO;
  }
  _preEditSelectedRange = _lastSelectedRange;
  _preEditReplacementLength = range.length;
  _preEditReplacementHasNewline =
      [text rangeOfCharacterFromSet:[NSCharacterSet newlineCharacterSet]].location != NSNotFound;
  [self capturePreEditBlockForRange:range];
  _isTextChanging = YES;
  [self stripLinkTypingAttributes];
  return YES;
}

/// Records the block kind/depth of the line being edited before the change, so a
/// replacement that wipes the attribute-bearing characters (autocorrect, paste)
/// can be healed afterward.
- (void)capturePreEditBlockForRange:(NSRange)range
{
  _preEditBlockType = ENRMInputBlockTypeParagraph;
  _preEditListDepth = 0;

  NSTextStorage *storage = _textView.textStorage;
  NSString *text = storage.string;
  if (text.length == 0) {
    return;
  }
  NSUInteger probe = MIN(range.location, text.length - 1);
  NSRange paragraphRange = [text paragraphRangeForRange:NSMakeRange(probe, 0)];
  if (paragraphRange.location >= text.length || [text characterAtIndex:paragraphRange.location] == '\n') {
    return;
  }
  id type = [storage attribute:ENRMBlockTypeAttributeName atIndex:paragraphRange.location effectiveRange:NULL];
  if (!type) {
    return;
  }
  _preEditBlockType = (ENRMInputBlockType)[type integerValue];
  if (_preEditBlockType == ENRMInputBlockTypeUnorderedListItem) {
    id depthValue = [storage attribute:ENRMListDepthAttributeName atIndex:paragraphRange.location effectiveRange:NULL];
    _preEditListDepth = depthValue ? [depthValue integerValue] : 0;
  }
}

/// Re-applies the edited line's block attribute across its whole content after an
/// in-line replacement (autocorrect/paste) that may have overwritten the
/// attribute-bearing characters. Prefers any block attribute that survived
/// somewhere on the line, falling back to the kind captured before the edit.
- (void)healCurrentLineBlockAttribute
{
  NSTextStorage *storage = _textView.textStorage;
  if (storage.length == 0) {
    return;
  }
  NSString *plain = storage.string;
  NSUInteger loc = MIN(_textView.selectedRange.location, plain.length);
  NSRange content = [plain paragraphRangeForRange:NSMakeRange(loc, 0)];
  if (content.length > 0 && [plain characterAtIndex:NSMaxRange(content) - 1] == '\n') {
    content.length -= 1;
  }
  if (content.length == 0) {
    return;
  }

  __block ENRMInputBlockType type = ENRMInputBlockTypeParagraph;
  __block NSInteger depth = 0;
  [storage enumerateAttribute:ENRMBlockTypeAttributeName
                      inRange:content
                      options:0
                   usingBlock:^(id value, NSRange attrRange, BOOL *stop) {
                     if (value) {
                       type = (ENRMInputBlockType)[value integerValue];
                       if (type == ENRMInputBlockTypeUnorderedListItem) {
                         id depthValue = [storage attribute:ENRMListDepthAttributeName
                                                    atIndex:attrRange.location
                                             effectiveRange:NULL];
                         depth = depthValue ? [depthValue integerValue] : 0;
                       }
                       *stop = YES;
                     }
                   }];

  if (type == ENRMInputBlockTypeParagraph && _preEditBlockType != ENRMInputBlockTypeParagraph) {
    type = _preEditBlockType;
    depth = _preEditListDepth;
  }
  if (type == ENRMInputBlockTypeParagraph) {
    return;
  }

  [storage addAttribute:ENRMBlockTypeAttributeName value:@(type) range:content];
  if (type == ENRMInputBlockTypeUnorderedListItem) {
    [storage addAttribute:ENRMListDepthAttributeName value:@(depth) range:content];
  } else {
    [storage removeAttribute:ENRMListDepthAttributeName range:content];
  }
}

/// Intercepts Tab (indent) and Backspace at the start of a list item (outdent,
/// then un-list at depth 0) so list nesting is keyboard-editable. Returns YES if
/// the edit was handled and the default text change should be suppressed.
- (BOOL)handleListKeyForReplacementRange:(NSRange)range replacementText:(NSString *)text
{
  if ([self blockTypeForCursorParagraph] != ENRMInputBlockTypeUnorderedListItem) {
    return NO;
  }

  // Tab indents the current item.
  if ([text isEqualToString:@"\t"]) {
    [self indentList];
    return YES;
  }

  // Backspace at the very start of an item's content: outdent, or remove the
  // list marker entirely once at depth 0.
  if (text.length == 0 && range.length == 1) {
    NSString *plainText = ENRMGetPlainText(_textView);
    NSRange paragraphRange = [plainText paragraphRangeForRange:NSMakeRange(NSMaxRange(range), 0)];
    BOOL atItemStart = NSMaxRange(range) == paragraphRange.location;
    if (atItemStart) {
      if ([self listDepthForCursorParagraph] > 0) {
        [self outdentList];
      } else {
        [self toggleUnorderedList];
      }
      return YES;
    }
  }

  return NO;
}

- (BOOL)handleBackspaceAtDocumentStart
{
  NSRange selection = _textView.selectedRange;
  if (selection.location != 0 || selection.length != 0) {
    return NO;
  }
  if ([self blockTypeForCursorParagraph] != ENRMInputBlockTypeUnorderedListItem) {
    return NO;
  }
  if ([self listDepthForCursorParagraph] > 0) {
    [self outdentList];
  } else {
    [self toggleUnorderedList];
  }
  return YES;
}

- (void)textViewDidChange:(UITextView *)textView
{
  if (_isApplyingFormatting) {
    return;
  }
  [self handleTextChanged];
  _isTextChanging = NO;
  _lastTextChangeTime = CACurrentMediaTime();
  _lastSelectedRange = textView.selectedRange;
}

- (void)textViewDidBeginEditing:(UITextView *)textView
{
  [self emitOnFocus];
}

- (void)textViewDidEndEditing:(UITextView *)textView
{
  [self clearActiveMention:nil];
  [self emitOnBlur];
}

- (void)textViewDidChangeSelection:(UITextView *)textView
{
  NSRange newSelection = textView.selectedRange;
  NSRange previousSelection = _lastSelectedRange;
  _lastSelectedRange = newSelection;

  if (_isApplyingFormatting || _isTextChanging) {
    return;
  }

  if (ENRMHasMarkedText(_textView)) {
    return;
  }

  BOOL selectionMoved =
      newSelection.location != previousSelection.location || newSelection.length != previousSelection.length;

  if (selectionMoved) {
    [self resetPendingStylesForSelectionChange];
  }

  [self manageSelectionBasedChanges];

  [self emitOnChangeSelection];
  [self updateActiveMention];
  [self emitOnChangeState];
  [self emitCaretRectChangeIfNeeded];
  [self updateEmptyBulletMarker];
}

#else

#pragma mark - RCTBackedTextInputDelegate (macOS)

- (BOOL)textInputShouldBeginEditing
{
  return YES;
}

- (void)textInputDidBeginEditing
{
  [self emitOnFocus];
}

- (BOOL)textInputShouldEndEditing
{
  return YES;
}

- (void)textInputDidEndEditing
{
  [self clearActiveMention:nil];
  [self emitOnBlur];
}

- (BOOL)textInputShouldReturn
{
  return NO;
}

- (void)textInputDidReturn
{
}

- (BOOL)textInputShouldSubmitOnReturn
{
  return NO;
}

- (nullable NSString *)textInputShouldChangeText:(NSString *)text inRange:(NSRange)range
{
  if ([self deleteLinkForReplacementRange:range replacementText:text]) {
    return nil;
  }
  _preEditSelectedRange = _lastSelectedRange;
  _isTextChanging = YES;
  return text;
}

- (void)textInputDidChange
{
  if (_isApplyingFormatting) {
    _isTextChanging = NO;
    return;
  }
  [self handleTextChanged];
  _isTextChanging = NO;
  _lastTextChangeTime = CACurrentMediaTime();
  _lastSelectedRange = _textView.selectedRange;
}

- (void)textInputDidChangeSelection
{
  NSRange newSelection = _textView.selectedRange;
  NSRange previousSelection = _lastSelectedRange;
  _lastSelectedRange = newSelection;

  if (_isApplyingFormatting || _isTextChanging) {
    return;
  }

  if (ENRMHasMarkedText(_textView)) {
    return;
  }

  BOOL selectionMoved =
      newSelection.location != previousSelection.location || newSelection.length != previousSelection.length;

  if (selectionMoved) {
    [self resetPendingStylesForSelectionChange];
  }

  [self emitOnChangeSelection];
  [self updateActiveMention];
  [self emitOnChangeState];
  [self emitCaretRectChangeIfNeeded];
}

// @required stubs for RCTBackedTextInputDelegate — RCTUITextView's internal adapter
// calls these via textInputDelegate; omitting any causes silent failures or crashes.

- (BOOL)textInputShouldHandleDeleteBackward:(id<RCTBackedTextInputViewProtocol>)sender
{
  return YES;
}

- (BOOL)textInputShouldHandleDeleteForward:(id<RCTBackedTextInputViewProtocol>)sender
{
  return YES;
}

- (BOOL)textInputShouldHandleKeyEvent:(NSEvent *)event
{
  return YES;
}

- (BOOL)hasKeyDownEventOrKeyUpEvent:(NSString *)key
{
  return NO;
}

- (NSDragOperation)textInputDraggingEntered:(id<NSDraggingInfo>)draggingInfo
{
  return NSDragOperationNone;
}

- (void)textInputDraggingExited:(id<NSDraggingInfo>)draggingInfo
{
}

- (BOOL)textInputShouldHandleDragOperation:(id<NSDraggingInfo>)draggingInfo
{
  return YES;
}

- (void)textInputDidCancel
{
}

- (BOOL)textInputShouldHandlePaste:(id<RCTBackedTextInputViewProtocol>)sender
{
  return YES;
}

- (void)automaticSpellingCorrectionDidChange:(BOOL)enabled
{
}

- (void)continuousSpellCheckingDidChange:(BOOL)enabled
{
}

- (void)grammarCheckingDidChange:(BOOL)enabled
{
}

- (void)submitOnKeyDownIfNeeded:(NSEvent *)event
{
}

#endif

@end

Class<RCTComponentViewProtocol> EnrichedMarkdownTextInputCls(void)
{
  return EnrichedMarkdownTextInput.class;
}
