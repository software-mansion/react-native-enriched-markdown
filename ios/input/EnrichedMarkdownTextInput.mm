#import "EnrichedMarkdownTextInput.h"
#import "ContextMenuUtils.h"
#import "ENRMAutoLinkDetector.h"
#import "ENRMDetectorPipeline.h"
#import "ENRMFormattingRange.h"
#import "ENRMFormattingStore.h"
#import "ENRMInputFormatter.h"
#import "ENRMInputLayoutManager.h"
#import "ENRMInputLinkPrompt.h"
#import "ENRMInputParser.h"
#import "ENRMInputTextView.h"
#import "ENRMLinkRegexConfig.h"
#import "ENRMMarkdownSerializer.h"
#import "ENRMStyleHandler.h"
#import "ENRMStyleMergingConfig.h"
#import "ENRMUIKit.h"
#import "InputStylePropsUtils.h"
#import "SelectionColorUtils.h"
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

  ENRMPlaceholderLabel *_placeholderLabel;

  NSUInteger _lastTextLength;
  NSRange _lastSelectedRange;
  NSRange _preEditSelectedRange;

  struct {
    BOOL bold, italic, underline, strikethrough, spoiler, link, initialized;
  } _prevState;

  std::optional<CGRect> _prevCaretRect;

#if TARGET_OS_OSX
  NSScrollView *_scrollView;
#endif

  NSArray<NSString *> *_contextMenuItemTexts;
  NSArray<NSString *> *_contextMenuItemIcons;

  ENRMAutoLinkDetector *_autoLinkDetector;
  ENRMDetectorPipeline *_detectorPipeline;
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

  BOOL styleChanged = applyInputStyleProps(_formatterStyle, newViewProps, oldViewProps);

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
  _placeholderLabel.hidden = (ENRMGetPlainText(_textView).length > 0);
}

#pragma mark - Markdown import

- (void)importMarkdown:(NSString *)markdown
{
  ENRMInputParser *parser = [[ENRMInputParser alloc] init];
  ENRMParseResult *parsed = [parser parseToPlainTextAndRanges:markdown];

  _blockEmitting = YES;

  _isApplyingFormatting = YES;
  ENRMSetPlainText(_textView, parsed.plainText);
  _isApplyingFormatting = NO;

  [_formattingStore setRanges:parsed.formattingRanges];
  _lastTextLength = parsed.plainText.length;
  _lastSelectedRange = _textView.selectedRange;
  [self applyFormatting];
  [self updatePlaceholderVisibility];

  _blockEmitting = NO;
}

- (void)replaceSelectedTextWith:(NSString *)text formattingRanges:(NSArray<ENRMFormattingRange *> *)ranges
{
  NSRange selection = _textView.selectedRange;
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

  NSUInteger textLen = ENRMGetPlainText(_textView).length;
  if (savedSelection.location + savedSelection.length <= textLen) {
    _textView.selectedRange = savedSelection;
  }

  _isApplyingFormatting = NO;
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
  ENRMFormattingRange *range = [ENRMFormattingRange rangeWithType:ENRMInputStyleTypeLink range:linkRange url:url];
  [self replaceSelectedTextWith:displayText formattingRanges:@[ range ]];
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
                                                           ranges:[self allRangesIncludingTransient]];
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
                                                           ranges:[self allRangesIncludingTransient]];
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

  if (_prevState.initialized && _prevState.bold == boldActive && _prevState.italic == italicActive &&
      _prevState.underline == underlineActive && _prevState.strikethrough == strikethroughActive &&
      _prevState.spoiler == spoilerActive && _prevState.link == linkActive) {
    return;
  }

  _prevState.bold = boldActive;
  _prevState.italic = italicActive;
  _prevState.underline = underlineActive;
  _prevState.strikethrough = strikethroughActive;
  _prevState.spoiler = spoilerActive;
  _prevState.link = linkActive;
  _prevState.initialized = YES;

  emitter->onChangeState({
      .bold = {.isActive = boldActive},
      .italic = {.isActive = italicActive},
      .underline = {.isActive = underlineActive},
      .strikethrough = {.isActive = strikethroughActive},
      .spoiler = {.isActive = spoilerActive},
      .link = {.isActive = linkActive},
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

    for (NSNumber *styleNum in _pendingStyles) {
      ENRMFormattingRange *newRange = [ENRMFormattingRange rangeWithType:(ENRMInputStyleType)styleNum.integerValue
                                                                   range:insertedRange];
      [_formattingStore addRange:newRange];
    }

    // adjustForEditAtLocation may have expanded an existing range to cover
    // the insertion — carve out the inserted portion for removed styles.
    for (NSNumber *styleNum in _pendingStyleRemovals) {
      [_formattingStore removeType:(ENRMInputStyleType)styleNum.integerValue inRange:insertedRange];
    }
  }

  _lastTextLength = newLength;

#if !TARGET_OS_OSX
  if (newLength == 0) {
    [self resetBaseTypingAttributes];
  }
#endif

  [self applyFormatting];

  NSUInteger clampedEditLocation = MIN(editLocation, newLength);
  NSUInteger clampedInsertedLength = MIN(insertedLength, newLength - clampedEditLocation);
  [_detectorPipeline processTextChange:ENRMGetPlainText(_textView)
                     modificationRange:NSMakeRange(clampedEditLocation, clampedInsertedLength)];

  [self updatePlaceholderVisibility];
  [self emitOnChangeText];
  [self emitOnChangeSelection];
  [self emitFormattingChanged];
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
        NSMutableDictionary *attrs = [NSMutableDictionary dictionary];
        attrs[NSFontAttributeName] = _formatterStyle.baseFont;
        attrs[NSForegroundColorAttributeName] = _formatterStyle.baseTextColor;
        _textView.typingAttributes = attrs;
      }
    }
  }
}

- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text
{
  _preEditSelectedRange = _lastSelectedRange;
  _isTextChanging = YES;
  [self stripLinkTypingAttributes];
  return YES;
}

- (void)textViewDidChange:(UITextView *)textView
{
  if (_isApplyingFormatting) {
    return;
  }
  [self handleTextChanged];
  _isTextChanging = NO;
  _lastSelectedRange = textView.selectedRange;
}

- (void)textViewDidBeginEditing:(UITextView *)textView
{
  [self emitOnFocus];
}

- (void)textViewDidEndEditing:(UITextView *)textView
{
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

  BOOL selectionMoved =
      newSelection.location != previousSelection.location || newSelection.length != previousSelection.length;

  if (selectionMoved) {
    [_pendingStyles removeAllObjects];
    [_pendingStyleRemovals removeAllObjects];
  }

  [self manageSelectionBasedChanges];

  [self emitOnChangeSelection];
  [self emitOnChangeState];
  [self emitCaretRectChangeIfNeeded];
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
  _lastSelectedRange = _textView.selectedRange;
}

- (void)textInputDidChangeSelection
{
  _lastSelectedRange = _textView.selectedRange;

  if (_isApplyingFormatting || _isTextChanging) {
    return;
  }

  [_pendingStyles removeAllObjects];
  [_pendingStyleRemovals removeAllObjects];

  [self emitOnChangeSelection];
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
