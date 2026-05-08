#import "EnrichedMarkdown.h"
#import "ContextMenuUtils.h"
#import "ENRMAsyncRenderCoordinator.h"
#import "ENRMImageAttachment.h"
#import "ENRMMarkdownParser.h"
#import "ENRMTailFadeInAnimator.h"
#import "ENRMTextInteractionUtils.h"
#import "ENRMTextRenderer.h"
#import "ENRMTextViewSetup.h"
#import "ENRMUIKit.h"
#import "EditMenuUtils.h"

#import "ENRMFeatureFlags.h"

#if ENRICHED_MARKDOWN_MATH
#import "ENRMMathContainerView.h"
#endif
#import "ENRMSpoilerCapable.h"
#import "ENRMSpoilerOverlayView.h"
#import "ENRMSpoilerTapUtils.h"
#import "EnrichedMarkdownInternalText.h"
#import "FontScaleObserver.h"
#import "FontUtils.h"
#import "HeightUpdateUtils.h"
#import "LastElementUtils.h"
#import "LinkTapUtils.h"
#import "MarkdownASTNode.h"
#import "MarkdownAccessibilityElementBuilder.h"
#import "MarkdownExtractor.h"
#import "RenderedMarkdownSegment.h"
#import "RuntimeKeys.h"
#import "SegmentReconciler.h"
#import "SegmentRenderer.h"
#import "SegmentViewRegistry.h"
#import "SelectionColorUtils.h"
#import "StreamingMarkdownFilter.h"
#import "StyleConfig.h"
#import "StylePropsUtils.h"
#import "TableContainerView.h"
#import "TaskListTapUtils.h"
#import "TextViewLayoutManager.h"
#import <React/RCTUtils.h>
#import <objc/runtime.h>

#import <ReactNativeEnrichedMarkdown/EnrichedMarkdownComponentDescriptor.h>
#import <ReactNativeEnrichedMarkdown/EventEmitters.h>
#import <ReactNativeEnrichedMarkdown/Props.h>
#import <ReactNativeEnrichedMarkdown/RCTComponentViewHelpers.h>

#import "RCTFabricComponentsPlugins.h"
#import <React/RCTConversions.h>
#import <React/RCTFont.h>

using namespace facebook::react;

typedef NS_OPTIONS(NSUInteger, ENRMDirtyFlags) {
  ENRMDirtyNone = 0,
  ENRMDirtyRecreateSegments = 1 << 0,
  ENRMDirtyForceHeight = 1 << 1,
};

static char kENRMSegmentFadeAnimatorKey;

@interface EnrichedMarkdown () <RCTEnrichedMarkdownViewProtocol, UITextViewDelegate>
- (void)emitLinkPress:(NSString *)url;
- (void)emitLinkLongPress:(NSString *)url;
- (void)emitTaskListItemPress:(NSInteger)index checked:(BOOL)checked text:(NSString *)text;
- (void)emitContextMenuItemPress:(NSString *)itemText
                    selectedText:(NSString *)selectedText
                  selectionStart:(NSUInteger)selectionStart
                    selectionEnd:(NSUInteger)selectionEnd;
@end

@implementation EnrichedMarkdown {
  ENRMMarkdownParser *_parser;
  StyleConfig *_config;
  ENRMMd4cFlags *_md4cFlags;
  NSString *_cachedMarkdown;
  NSString *_renderedMarkdown;
  NSMutableArray<RCTUIView *> *_segmentViews;
  NSMutableArray<NSNumber *> *_segmentSignatures;
  ENRMSegmentViewRegistry *_segmentViewRegistry;
  ENRMDirtyFlags _dirtyFlags;

  ENRMAsyncRenderCoordinator *_renderCoordinator;

  EnrichedMarkdownShadowNode::ConcreteState::Shared _state;
  int _heightUpdateCounter;

  FontScaleObserver *_fontScaleObserver;
  CGFloat _maxFontSizeMultiplier;

  BOOL _allowTrailingMargin;
  BOOL _selectable;
  BOOL _enableLinkPreview;
  BOOL _streamingAnimation;
  ENRMTableStreamingMode _tableStreamingMode;

  NSArray<NSString *> *_contextMenuItemTexts;
  NSArray<NSString *> *_contextMenuItemIcons;
  ENRMSelectionMenuConfig _selectionMenuConfig;

  ENRMSpoilerOverlay _spoilerOverlay;
}

+ (ComponentDescriptorProvider)componentDescriptorProvider
{
  return concreteComponentDescriptorProvider<EnrichedMarkdownComponentDescriptor>();
}

- (instancetype)initWithFrame:(CGRect)frame
{
  if (self = [super initWithFrame:frame]) {
    static const auto defaultProps = std::make_shared<const EnrichedMarkdownProps>();
    _props = defaultProps;

    self.backgroundColor = [RCTUIColor clearColor];
    _parser = [[ENRMMarkdownParser alloc] init];
    _md4cFlags = [ENRMMd4cFlags defaultFlags];
    _segmentViews = [NSMutableArray array];
    _segmentSignatures = [NSMutableArray array];
    _dirtyFlags = ENRMDirtyNone;
    [self configureSegmentViewRegistry];

    _renderCoordinator =
        [[ENRMAsyncRenderCoordinator alloc] initWithQueueLabel:"com.swmansion.enriched.markdown.container.render"];

    _maxFontSizeMultiplier = 0;
    _allowTrailingMargin = NO;
    _selectable = YES;
    _enableLinkPreview = YES;
    _streamingAnimation = NO;
    _tableStreamingMode = ENRMTableStreamingModeHidden;
    _selectionMenuConfig = (ENRMSelectionMenuConfig){.copyAsMarkdown = YES, .copyImageURL = YES};

    _fontScaleObserver = [[FontScaleObserver alloc] init];
    __weak EnrichedMarkdown *weakSelf = self;
    _fontScaleObserver.onChange = ^{
      EnrichedMarkdown *strongSelf = weakSelf;
      if (!strongSelf)
        return;
      if (strongSelf->_config != nil) {
        [strongSelf->_config setFontScaleMultiplier:strongSelf->_fontScaleObserver.effectiveFontScale];
      }
      if (strongSelf->_cachedMarkdown != nil && strongSelf->_cachedMarkdown.length > 0) {
        strongSelf->_dirtyFlags |= ENRMDirtyRecreateSegments | ENRMDirtyForceHeight;
        [strongSelf renderMarkdownContent:strongSelf->_cachedMarkdown];
      }
    };
  }
  return self;
}

- (void)configureSegmentViewRegistry
{
  __weak EnrichedMarkdown *weakSelf = self;
  NSMutableArray<ENRMSegmentViewHandler *> *handlers = [NSMutableArray array];

  [handlers addObject:[ENRMSegmentViewHandler handlerWithKind:ENRMSegmentKindText
                          matchesView:^BOOL(RCTUIView *view, ENRMRenderedSegment *segment) {
                            return [view isKindOfClass:[EnrichedMarkdownInternalText class]];
                          }
                          createView:^RCTUIView *(ENRMRenderedSegment *segment) {
                            EnrichedMarkdown *strongSelf = weakSelf;
                            if (!strongSelf) {
                              return [[RCTUIView alloc] init];
                            }

                            EnrichedMarkdownInternalText *view =
                                [strongSelf createTextViewForRenderedSegment:segment.textResult];
                            [strongSelf animateTextView:view fromTailStart:0];
                            return view;
                          }
                          updateView:^(RCTUIView *view, ENRMRenderedSegment *segment) {
                            EnrichedMarkdown *strongSelf = weakSelf;
                            if (strongSelf) {
                              [strongSelf updateTextView:(EnrichedMarkdownInternalText *)view
                                     withRenderedSegment:segment.textResult];
                            }
                          }]];

  [handlers addObject:[ENRMSegmentViewHandler handlerWithKind:ENRMSegmentKindTable
                          matchesView:^BOOL(RCTUIView *view, ENRMRenderedSegment *segment) {
                            return [view isKindOfClass:[TableContainerView class]];
                          }
                          createView:^RCTUIView *(ENRMRenderedSegment *segment) {
                            EnrichedMarkdown *strongSelf = weakSelf;
                            if (!strongSelf) {
                              return [[RCTUIView alloc] init];
                            }

                            TableContainerView *view = [strongSelf createTableViewForSegment:segment.tableSegment];
                            [strongSelf animateBlockViewIfNeeded:view];
                            return view;
                          }
                          updateView:^(RCTUIView *view, ENRMRenderedSegment *segment) {
                            EnrichedMarkdown *strongSelf = weakSelf;
                            if (strongSelf) {
                              [strongSelf updateTableView:(TableContainerView *)view withSegment:segment.tableSegment];
                            }
                          }]];

#if ENRICHED_MARKDOWN_MATH
  [handlers addObject:[ENRMSegmentViewHandler handlerWithKind:ENRMSegmentKindMath
                          matchesView:^BOOL(RCTUIView *view, ENRMRenderedSegment *segment) {
                            return [view isKindOfClass:[ENRMMathContainerView class]];
                          }
                          createView:^RCTUIView *(ENRMRenderedSegment *segment) {
                            EnrichedMarkdown *strongSelf = weakSelf;
                            if (!strongSelf) {
                              return [[RCTUIView alloc] init];
                            }

                            ENRMMathContainerView *view =
                                [strongSelf createMathViewForSegment:(ENRMMathSegment *)segment.mathSegment];
                            [strongSelf animateBlockViewIfNeeded:view];
                            return view;
                          }
                          updateView:^(RCTUIView *view, ENRMRenderedSegment *segment) {
                            [(ENRMMathContainerView *)view applyLatex:((ENRMMathSegment *)segment.mathSegment).latex];
                          }]];
#endif

  _segmentViewRegistry = [[ENRMSegmentViewRegistry alloc] initWithHandlers:handlers];
}

- (CGSize)computeSegmentLayoutForWidth:(CGFloat)width applyFrames:(BOOL)applyFrames
{
  if (_segmentViews.count == 0)
    return CGSizeZero;

  __block CGFloat yOffset = 0.0;
  __block CGFloat maxContentWidth = 0.0;
  const NSUInteger lastIndex = _segmentViews.count - 1;

  [_segmentViews enumerateObjectsUsingBlock:^(RCTUIView *segment, NSUInteger i, BOOL *stop) {
    const BOOL isLast = (i == lastIndex);
    const BOOL shouldAddBottomMargin = (!isLast || _allowTrailingMargin);

    CGFloat segmentHeight = 0;

    if ([segment isKindOfClass:[EnrichedMarkdownInternalText class]]) {
      EnrichedMarkdownInternalText *textView = (EnrichedMarkdownInternalText *)segment;
      textView.allowTrailingMargin = shouldAddBottomMargin;
      CGSize textSize = [textView measureSize:width];
      segmentHeight = textSize.height;
      maxContentWidth = MAX(maxContentWidth, textSize.width);

    } else if ([segment isKindOfClass:[TableContainerView class]]) {
      yOffset += _config.tableMarginTop;
      segmentHeight = [(TableContainerView *)segment measureHeight:width];
      maxContentWidth = width;
    }
#if ENRICHED_MARKDOWN_MATH
    else if ([segment isKindOfClass:[ENRMMathContainerView class]]) {
      yOffset += _config.mathMarginTop;
      segmentHeight = [(ENRMMathContainerView *)segment measureHeight:width];
      maxContentWidth = width;
    }
#endif

    if (applyFrames) {
      CGRect segmentFrame = CGRectMake(0, yOffset, width, segmentHeight);
      segment.frame = segmentFrame;
#if TARGET_OS_OSX
      if ([segment isKindOfClass:[EnrichedMarkdownInternalText class]]) {
        EnrichedMarkdownInternalText *textSeg = (EnrichedMarkdownInternalText *)segment;
        textSeg.textView.frame = segment.bounds;
        textSeg.textView.textContainer.size = CGSizeMake(width, CGFLOAT_MAX);
        [textSeg.textView.layoutManager ensureLayoutForTextContainer:textSeg.textView.textContainer];
        ENRMSetNeedsDisplay(textSeg.textView);
      }
#endif
    }

    yOffset += segmentHeight;

    if ([segment isKindOfClass:[TableContainerView class]] && shouldAddBottomMargin) {
      yOffset += _config.tableMarginBottom;
    }
#if ENRICHED_MARKDOWN_MATH
    else if ([segment isKindOfClass:[ENRMMathContainerView class]] && shouldAddBottomMargin) {
      yOffset += _config.mathMarginBottom;
    }
#endif
  }];

  return CGSizeMake(maxContentWidth, yOffset);
}

- (CGSize)measureSize:(CGFloat)maxWidth
{
  CGFloat defaultHeight = UIFontLineHeight([UIFont systemFontOfSize:16.0]);
  CGSize contentSize = [self computeSegmentLayoutForWidth:maxWidth applyFrames:NO];
  if (contentSize.height == 0)
    return CGSizeMake(maxWidth, defaultHeight);

  CGFloat scale = RCTScreenScale();
  CGFloat measuredWidth = MIN(ceil(contentSize.width * scale) / scale, maxWidth);
  CGFloat measuredHeight = ceil(contentSize.height * scale) / scale;
  return CGSizeMake(measuredWidth, measuredHeight);
}

- (BOOL)hasRenderedMarkdown:(NSString *)markdown
{
  return _renderedMarkdown != nil && [_renderedMarkdown isEqualToString:markdown];
}

- (BOOL)renderedSegmentsChangeTopology:(NSArray<ENRMRenderedSegment *> *)renderedSegments
{
  if (renderedSegments.count != _segmentViews.count) {
    return YES;
  }

  for (NSUInteger index = 0; index < renderedSegments.count; index++) {
    if (![_segmentViewRegistry view:_segmentViews[index] matchesSegment:renderedSegments[index]]) {
      return YES;
    }
  }

  return NO;
}

- (void)updateState:(const facebook::react::State::Shared &)state
           oldState:(const facebook::react::State::Shared &)oldState
{
  _state = std::static_pointer_cast<const EnrichedMarkdownShadowNode::ConcreteState>(state);

  if (oldState == nullptr) {
    [self requestHeightUpdate];
  }
}

- (void)requestHeightUpdate
{
  ENRMRequestHeightUpdate<EnrichedMarkdownState>(_state, _heightUpdateCounter, self);
}

- (void)renderMarkdownContent:(NSString *)markdownString
{
  if (_renderCoordinator.blockAsyncRender)
    return;

  _cachedMarkdown = [markdownString copy];

  StyleConfig *config = [_config copy];
  ENRMMarkdownParser *parser = _parser;
  ENRMMd4cFlags *md4cFlags = [_md4cFlags copy];

  BOOL allowFontScaling = _fontScaleObserver.allowFontScaling;
  CGFloat maxFontSizeMultiplier = _maxFontSizeMultiplier;
  BOOL allowTrailingMargin = _allowTrailingMargin;
  BOOL streamingAnimation = _streamingAnimation;
  ENRMTableStreamingMode tableStreamingMode = _tableStreamingMode;

  __block NSArray<ENRMRenderedSegment *> *renderedSegments = nil;
  __block NSString *renderableMarkdown = nil;

  [_renderCoordinator
      scheduleRender:^BOOL {
        renderableMarkdown = streamingAnimation ? ENRMRenderableMarkdownForStreaming(markdownString, tableStreamingMode)
                                                : markdownString;

        if (renderableMarkdown.length == 0) {
          renderedSegments = @[];
          return YES;
        }

        MarkdownASTNode *ast = [parser parseMarkdown:renderableMarkdown flags:md4cFlags];
        if (!ast)
          return NO;

        renderedSegments =
            ENRMRenderSegmentsFromAST(ast, config, allowTrailingMargin, allowFontScaling, maxFontSizeMultiplier);
        return YES;
      }
      apply:^{ [self applyRenderedSegments:renderedSegments renderedMarkdown:renderableMarkdown]; }];
}

- (NSArray *)parseAndRenderSegments:(NSString *)markdownString
{
  MarkdownASTNode *ast = [_parser parseMarkdown:markdownString flags:_md4cFlags];
  if (!ast) {
    return nil;
  }

  return ENRMRenderSegmentsFromAST(ast, _config, _allowTrailingMargin, _fontScaleObserver.allowFontScaling,
                                   _maxFontSizeMultiplier);
}

/// Synchronous rendering for mock view measurement (no UI updates needed).
- (void)renderMarkdownSynchronously:(NSString *)markdownString
{
  if (!markdownString || markdownString.length == 0) {
    return;
  }

  for (RCTUIView *view in _segmentViews) {
    [view removeFromSuperview];
  }
  [_segmentViews removeAllObjects];
  [_segmentSignatures removeAllObjects];

  _renderCoordinator.blockAsyncRender = YES;
  _cachedMarkdown = [markdownString copy];
  NSString *renderableMarkdown =
      _streamingAnimation ? ENRMRenderableMarkdownForStreaming(markdownString, _tableStreamingMode) : markdownString;
  _renderedMarkdown = [renderableMarkdown copy];

  if (renderableMarkdown.length == 0) {
    return;
  }

  NSArray *renderedSegments = [self parseAndRenderSegments:renderableMarkdown];
  if (!renderedSegments) {
    return;
  }

  for (ENRMRenderedSegment *segment in renderedSegments) {
    RCTUIView *view = [_segmentViewRegistry createViewForSegment:segment];
    [_segmentViews addObject:view];
    [_segmentSignatures addObject:@(segment.signature)];
    [self addSubview:view];
  }
}

- (void)applyRenderedSegments:(NSArray *)renderedSegments renderedMarkdown:(NSString *)renderedMarkdown
{
  _renderedMarkdown = [renderedMarkdown copy];
  BOOL segmentTopologyChanged = _streamingAnimation && [self renderedSegmentsChangeTopology:renderedSegments];

  ENRMSegmentReconciliationResult *result = [ENRMSegmentReconciler reconcileCurrentViews:_segmentViews
      currentSignatures:_segmentSignatures
      renderedSegments:renderedSegments
      reset:(_dirtyFlags & ENRMDirtyRecreateSegments) != 0
      createView:^RCTUIView *(ENRMRenderedSegment *segment) {
        return [self->_segmentViewRegistry createViewForSegment:segment];
      }
      updateView:^(RCTUIView *view, ENRMRenderedSegment *segment) {
        [self->_segmentViewRegistry updateView:view withSegment:segment];
      }
      attachView:^(RCTUIView *view) { [self addSubview:view]; }
      removeView:^(RCTUIView *view) { [view removeFromSuperview]; }
      matchesKind:^BOOL(RCTUIView *view, ENRMRenderedSegment *segment) {
        return [self->_segmentViewRegistry view:view matchesSegment:segment];
      }];
  BOOL forceHeightUpdate = (_dirtyFlags & ENRMDirtyForceHeight) != 0;
  _dirtyFlags = ENRMDirtyNone;

  _segmentViews = result.views;
  _segmentSignatures = result.signatures;

  if (self.bounds.size.width > 0) {
    [self setNeedsLayout];

    if (forceHeightUpdate || segmentTopologyChanged) {
      [self computeSegmentLayoutForWidth:self.bounds.size.width applyFrames:YES];
      [self layoutIfNeeded];
      [self requestHeightUpdate];
    } else {
      CGSize measured = [self measureSize:self.bounds.size.width];
      if (needsHeightUpdate(measured, self.bounds)) {
        [self requestHeightUpdate];
      }
    }
  }
}

- (void)configureTextView:(EnrichedMarkdownInternalText *)view withRenderedSegment:(ENRMRenderResult *)segment
{
  view.spoilerOverlay = _spoilerOverlay;
  view.allowTrailingMargin = _allowTrailingMargin;
  view.lastElementMarginBottom = segment.lastElementMarginBottom;
  view.accessibilityInfo = segment.accessibilityInfo;
  view.textView.selectable = _selectable;
  [view applyAttributedText:segment.attributedText context:segment.context];

  const auto &selectionProps = *std::static_pointer_cast<EnrichedMarkdownProps const>(self->_props);
  ENRMApplySelectionColor(view.textView, selectionProps.selectionColor);
}

- (EnrichedMarkdownInternalText *)createTextViewForRenderedSegment:(ENRMRenderResult *)segment
{
  EnrichedMarkdownInternalText *view = [[EnrichedMarkdownInternalText alloc] initWithConfig:_config];
  [self configureTextView:view withRenderedSegment:segment];

  ENRMTapRecognizer *tapRecognizer = [[ENRMTapRecognizer alloc] initWithTarget:self action:@selector(textTapped:)];
  [view.textView addGestureRecognizer:tapRecognizer];

#if !TARGET_OS_OSX
  view.textView.delegate = self;
#else
  __weak EnrichedMarkdown *weakSelf = self;
  [view setContextMenuProvider:^NSMenu *_Nullable(NSMenu *baseMenu, NSTextView *textView) {
    EnrichedMarkdown *strongSelf = weakSelf;
    if (!strongSelf) {
      return baseMenu;
    }
    NSString *segmentMarkdown = extractMarkdownFromAttributedString(textView.textStorage, textView.selectedRange);
    NSArray<NSMenuItem *> *customItems = ENRMBuildContextMenuItems(
        strongSelf->_contextMenuItemTexts, strongSelf->_contextMenuItemIcons, textView,
        ^(NSString *itemText, NSString *selectedText, NSUInteger selectionStart, NSUInteger selectionEnd) {
          [strongSelf emitContextMenuItemPress:itemText
                                  selectedText:selectedText
                                selectionStart:selectionStart
                                  selectionEnd:selectionEnd];
        });
    return buildEditMenuForSelection(textView.textStorage, textView.selectedRange, segmentMarkdown, strongSelf->_config,
                                     @[ baseMenu ], customItems, strongSelf -> _selectionMenuConfig);
  }];
#endif

  return view;
}

- (TableContainerView *)createTableViewForSegment:(ENRMTableSegment *)tableSegment
{
  TableContainerView *tableView = [[TableContainerView alloc] initWithConfig:_config];

  tableView.allowFontScaling = _fontScaleObserver.allowFontScaling;
  tableView.maxFontSizeMultiplier = _maxFontSizeMultiplier;
  tableView.enableLinkPreview = _enableLinkPreview;

  __weak EnrichedMarkdown *weakSelf = self;

  tableView.onLinkPress = ^(NSString *url) {
    EnrichedMarkdown *strongSelf = weakSelf;
    if (strongSelf && url)
      [strongSelf emitLinkPress:url];
  };

  tableView.onLinkLongPress = ^(NSString *url) {
    EnrichedMarkdown *strongSelf = weakSelf;
    if (strongSelf && url)
      [strongSelf emitLinkLongPress:url];
  };

  [tableView applyTableNode:tableSegment.tableNode];

  return tableView;
}

- (void)updateTableView:(TableContainerView *)view withSegment:(ENRMTableSegment *)tableSegment
{
  NSUInteger previousRowCount = view.rowCount;
  [view applyTableNode:tableSegment.tableNode];

  if (_streamingAnimation) {
    [view animateNewRowsFromPreviousCount:previousRowCount duration:0.20];
  }
}

#if ENRICHED_MARKDOWN_MATH
- (ENRMMathContainerView *)createMathViewForSegment:(ENRMMathSegment *)mathSegment
{
  ENRMMathContainerView *mathView = [[ENRMMathContainerView alloc] initWithConfig:_config];
  [mathView applyLatex:mathSegment.latex];
  return mathView;
}
#endif

- (void)animateBlockViewIfNeeded:(RCTUIView *)view
{
  if (!_streamingAnimation)
    return;

#if !TARGET_OS_OSX
  view.alpha = 0.0;
  [UIView animateWithDuration:0.20 animations:^{ view.alpha = 1.0; }];
#endif
}

- (void)animateTextView:(EnrichedMarkdownInternalText *)view fromTailStart:(NSUInteger)tailStart
{
  if (!_streamingAnimation)
    return;

  ENRMTailFadeInAnimator *animator = objc_getAssociatedObject(view.textView, &kENRMSegmentFadeAnimatorKey);
  if (!animator) {
    animator = [[ENRMTailFadeInAnimator alloc] initWithTextView:view.textView];
    objc_setAssociatedObject(view.textView, &kENRMSegmentFadeAnimatorKey, animator, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  }

  [animator animateFrom:tailStart to:ENRMGetAttributedText(view.textView).length];
}

- (void)updateTextView:(EnrichedMarkdownInternalText *)view withRenderedSegment:(ENRMRenderResult *)segment
{
  NSUInteger tailStart = ENRMGetAttributedText(view.textView).length;
  [self configureTextView:view withRenderedSegment:segment];
  [self animateTextView:view fromTailStart:tailStart];
}

- (void)layoutSubviews
{
  [super layoutSubviews];
  [self computeSegmentLayoutForWidth:self.bounds.size.width applyFrames:YES];
}

- (void)updateProps:(Props::Shared const &)props oldProps:(Props::Shared const &)oldProps
{
  const auto &oldViewProps = *std::static_pointer_cast<EnrichedMarkdownProps const>(_props);
  const auto &newViewProps = *std::static_pointer_cast<EnrichedMarkdownProps const>(props);

  BOOL stylePropChanged = NO;
  BOOL markdownChanged = oldViewProps.markdown != newViewProps.markdown;

  if (_config == nil) {
    _config = [[StyleConfig alloc] init];
    [_config setFontScaleMultiplier:_fontScaleObserver.effectiveFontScale];
  }

  stylePropChanged = applyMarkdownStyleToConfig(_config, newViewProps.markdownStyle, oldViewProps.markdownStyle);

  if (stylePropChanged) {
    [ENRMImageAttachment clearAttachmentRegistry];
    _dirtyFlags |= ENRMDirtyForceHeight;
    if (!markdownChanged) {
      _dirtyFlags |= ENRMDirtyRecreateSegments;
    }
  }

  _selectable = newViewProps.selectable;

  for (RCTUIView *segment in _segmentViews) {
    if ([segment isKindOfClass:[EnrichedMarkdownInternalText class]]) {
      EnrichedMarkdownInternalText *textSegment = (EnrichedMarkdownInternalText *)segment;
      if (textSegment.textView.selectable != newViewProps.selectable) {
        textSegment.textView.selectable = newViewProps.selectable;
      }
    }
  }

  if (newViewProps.allowFontScaling != oldViewProps.allowFontScaling) {
    _fontScaleObserver.allowFontScaling = newViewProps.allowFontScaling;
    if (_config != nil) {
      [_config setFontScaleMultiplier:_fontScaleObserver.effectiveFontScale];
    }
    stylePropChanged = YES;
    _dirtyFlags |= ENRMDirtyRecreateSegments | ENRMDirtyForceHeight;
  }

  if (newViewProps.maxFontSizeMultiplier != oldViewProps.maxFontSizeMultiplier) {
    _maxFontSizeMultiplier = newViewProps.maxFontSizeMultiplier;
    if (_config != nil) {
      [_config setMaxFontSizeMultiplier:_maxFontSizeMultiplier];
    }
    stylePropChanged = YES;
    _dirtyFlags |= ENRMDirtyRecreateSegments | ENRMDirtyForceHeight;
  }

  if (newViewProps.allowTrailingMargin != oldViewProps.allowTrailingMargin) {
    _allowTrailingMargin = newViewProps.allowTrailingMargin;
    _dirtyFlags |= ENRMDirtyRecreateSegments | ENRMDirtyForceHeight;
  }

  BOOL md4cFlagsChanged = NO;
  if (newViewProps.md4cFlags.underline != oldViewProps.md4cFlags.underline) {
    _md4cFlags.underline = newViewProps.md4cFlags.underline;
    md4cFlagsChanged = YES;
    _dirtyFlags |= ENRMDirtyForceHeight;
  }
  if (newViewProps.md4cFlags.superscript != oldViewProps.md4cFlags.superscript) {
    _md4cFlags.superscript = newViewProps.md4cFlags.superscript;
    md4cFlagsChanged = YES;
    _dirtyFlags |= ENRMDirtyForceHeight;
  }
  if (newViewProps.md4cFlags.subscript != oldViewProps.md4cFlags.subscript) {
    _md4cFlags.subscript = newViewProps.md4cFlags.subscript;
    md4cFlagsChanged = YES;
    _dirtyFlags |= ENRMDirtyForceHeight;
  }
  if (newViewProps.md4cFlags.latexMath != oldViewProps.md4cFlags.latexMath) {
    _md4cFlags.latexMath = newViewProps.md4cFlags.latexMath;
    md4cFlagsChanged = YES;
    _dirtyFlags |= ENRMDirtyForceHeight;
  }
  BOOL allowTrailingMarginChanged = newViewProps.allowTrailingMargin != oldViewProps.allowTrailingMargin;

  _enableLinkPreview = newViewProps.enableLinkPreview;

  BOOL streamingAnimationChanged = newViewProps.streamingAnimation != oldViewProps.streamingAnimation;
  if (streamingAnimationChanged) {
    _streamingAnimation = newViewProps.streamingAnimation;
    _dirtyFlags |= ENRMDirtyForceHeight;
    if (!_streamingAnimation) {
      for (RCTUIView *segment in _segmentViews) {
        if ([segment isKindOfClass:[EnrichedMarkdownInternalText class]]) {
          ENRMTailFadeInAnimator *animator = objc_getAssociatedObject(
              ((EnrichedMarkdownInternalText *)segment).textView, &kENRMSegmentFadeAnimatorKey);
          [animator cancel];
          objc_setAssociatedObject(((EnrichedMarkdownInternalText *)segment).textView, &kENRMSegmentFadeAnimatorKey,
                                   nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
      }
    }
  }

  BOOL streamingConfigChanged = NO;
  if (newViewProps.streamingConfig.tableMode != oldViewProps.streamingConfig.tableMode) {
    NSString *tableModeStr = [[NSString alloc] initWithUTF8String:newViewProps.streamingConfig.tableMode.c_str()];
    _tableStreamingMode = [tableModeStr isEqualToString:@"progressive"] ? ENRMTableStreamingModeProgressive
                                                                        : ENRMTableStreamingModeHidden;
    streamingConfigChanged = YES;
    _dirtyFlags |= ENRMDirtyForceHeight;
  }

  if (ENRMContextMenuItemsChanged(oldViewProps.contextMenuItems, newViewProps.contextMenuItems)) {
    _contextMenuItemTexts = ENRMContextMenuTextsFromItems(newViewProps.contextMenuItems);
    _contextMenuItemIcons = ENRMContextMenuIconsFromItems(newViewProps.contextMenuItems);
  }

  _selectionMenuConfig = (ENRMSelectionMenuConfig){
      .copyAsMarkdown = newViewProps.selectionMenuConfig.copyAsMarkdown,
      .copyImageURL = newViewProps.selectionMenuConfig.copyImageUrl,
  };

  if (newViewProps.spoilerOverlay != oldViewProps.spoilerOverlay) {
    NSString *modeStr = [[NSString alloc] initWithUTF8String:newViewProps.spoilerOverlay.c_str()];
    _spoilerOverlay = ENRMSpoilerOverlayFromString(modeStr);
    for (RCTUIView *segment in _segmentViews) {
      if ([segment isKindOfClass:[EnrichedMarkdownInternalText class]]) {
        ((EnrichedMarkdownInternalText *)segment).spoilerOverlay = _spoilerOverlay;
      }
    }
  }

  if (newViewProps.selectionColor != oldViewProps.selectionColor) {
    for (RCTUIView *segment in _segmentViews) {
      if ([segment isKindOfClass:[EnrichedMarkdownInternalText class]]) {
        ENRMPlatformTextView *tv = ((EnrichedMarkdownInternalText *)segment).textView;
        ENRMApplySelectionColor(tv, newViewProps.selectionColor);
      }
    }
  }

  if (markdownChanged || stylePropChanged || md4cFlagsChanged || allowTrailingMarginChanged ||
      streamingAnimationChanged || streamingConfigChanged) {
    NSString *markdownString = [[NSString alloc] initWithUTF8String:newViewProps.markdown.c_str()];
    [self renderMarkdownContent:markdownString];
  }

  [super updateProps:props oldProps:oldProps];
}

- (void)didMoveToWindow
{
  [super didMoveToWindow];

  if (self.window && _renderedMarkdown != nil) {
    for (RCTUIView *segment in _segmentViews) {
      if ([segment isKindOfClass:[EnrichedMarkdownInternalText class]]) {
        EnrichedMarkdownInternalText *textSegment = (EnrichedMarkdownInternalText *)segment;
        ENRMRefreshTextViewAfterWindowAttach(textSegment.textView, textSegment.bounds);
      }
    }

    CGSize measured = [self measureSize:self.bounds.size.width];
    if (needsHeightUpdate(measured, self.bounds)) {
      [self requestHeightUpdate];
    }
  }
}

Class<RCTComponentViewProtocol> EnrichedMarkdownCls(void)
{
  return EnrichedMarkdown.class;
}

#if !TARGET_OS_OSX
- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event
{
  if ([super pointInside:point withEvent:event]) {
    return YES;
  }

  for (RCTUIView *segment in _segmentViews) {
    if (CGRectContainsPoint(segment.frame, point)) {
      return YES;
    }
  }

  return NO;
}
#endif

- (facebook::react::SharedTouchEventEmitter)touchEventEmitterAtPoint:(CGPoint)point
{
  for (RCTUIView *segment in _segmentViews) {
    if ([segment isKindOfClass:[TableContainerView class]]) {
      CGPoint segmentPoint = [self convertPoint:point toView:segment];
#if !TARGET_OS_OSX
      if ([segment pointInside:segmentPoint withEvent:nil]) {
        return nil;
      }
#else
      if (CGRectContainsPoint(segment.bounds, segmentPoint)) {
        return nil;
      }
#endif
    }

    if (![segment isKindOfClass:[EnrichedMarkdownInternalText class]]) {
      continue;
    }
    EnrichedMarkdownInternalText *textSegment = (EnrichedMarkdownInternalText *)segment;
    CGPoint segmentPoint = [self convertPoint:point toView:textSegment.textView];
#if !TARGET_OS_OSX
    BOOL isInsideView = [textSegment.textView pointInside:segmentPoint withEvent:nil];
#else
    BOOL isInsideView = CGRectContainsPoint(textSegment.textView.bounds, segmentPoint);
#endif
    if (isInsideView) {
      if (isPointOnInteractiveElement(textSegment.textView, segmentPoint)) {
        return nil;
      }
      break;
    }
  }

  return [super touchEventEmitterAtPoint:point];
}

#if TARGET_OS_OSX
- (void)mouseDown:(NSEvent *)event
{
  for (RCTUIView *segment in _segmentViews) {
    if (![segment isKindOfClass:[EnrichedMarkdownInternalText class]]) {
      continue;
    }
    ENRMPlatformTextView *tv = ((EnrichedMarkdownInternalText *)segment).textView;
    if (tv.selectedRange.length > 0) {
      tv.selectedRange = NSMakeRange(0, 0);
    }
  }
  [super mouseDown:event];
}
#endif

- (void)emitLinkPress:(NSString *)url
{
  auto emitter = std::static_pointer_cast<EnrichedMarkdownEventEmitter const>(_eventEmitter);
  if (emitter)
    emitter->onLinkPress({.url = std::string(url.UTF8String)});
}

- (void)emitLinkLongPress:(NSString *)url
{
  auto emitter = std::static_pointer_cast<EnrichedMarkdownEventEmitter const>(_eventEmitter);
  if (emitter)
    emitter->onLinkLongPress({.url = std::string(url.UTF8String)});
}

- (void)emitTaskListItemPress:(NSInteger)index checked:(BOOL)checked text:(NSString *)text
{
  auto emitter = std::static_pointer_cast<EnrichedMarkdownEventEmitter const>(_eventEmitter);
  if (emitter)
    emitter->onTaskListItemPress({.index = (int)index, .checked = checked, .text = std::string(text.UTF8String ?: "")});
}

- (void)emitContextMenuItemPress:(NSString *)itemText
                    selectedText:(NSString *)selectedText
                  selectionStart:(NSUInteger)selectionStart
                    selectionEnd:(NSUInteger)selectionEnd
{
  auto emitter = std::static_pointer_cast<EnrichedMarkdownEventEmitter const>(_eventEmitter);
  if (emitter)
    emitter->onContextMenuItemPress({
        .itemText = std::string(itemText.UTF8String),
        .selectedText = std::string(selectedText.UTF8String),
        .selectionStart = (int)selectionStart,
        .selectionEnd = (int)selectionEnd,
    });
}

- (void)textTapped:(ENRMTapRecognizer *)recognizer
{
  ENRMPlatformTextView *textView = (ENRMPlatformTextView *)recognizer.view;

  if (handleTaskListTapWithSharedLogic(
          textView, recognizer, &self->_cachedMarkdown, self->_config,
          ^(NSInteger index, BOOL checked, NSString *itemText) {
            [self emitTaskListItemPress:index checked:checked text:itemText];
          },
          ^(NSString *updatedMarkdown) { [self renderMarkdownContent:updatedMarkdown]; })) {
    return;
  }

  for (RCTUIView *segment in _segmentViews) {
    if ([segment conformsToProtocol:@protocol(ENRMSpoilerCapable)]) {
      id<ENRMSpoilerCapable> spoilerSegment = (id<ENRMSpoilerCapable>)segment;
      if (spoilerSegment.textView == textView) {
        if (handleSpoilerTap(textView, recognizer, spoilerSegment.spoilerManager))
          return;
        break;
      }
    }
  }

  ENRMHandleTapOnTextView(textView, recognizer, ^(NSString *url) { [self emitLinkPress:url]; });
}

// TODO: Remove API_AVAILABLE(ios(16.0)) guard when the minimum iOS deployment target in RN is bumped to 16.
#if !TARGET_OS_OSX
- (UIMenu *)textView:(UITextView *)textView
    editMenuForTextInRange:(NSRange)range
          suggestedActions:(NSArray<UIMenuElement *> *)suggestedActions API_AVAILABLE(ios(16.0))
{
  __weak EnrichedMarkdown *weakSelf = self;
  ENRMContextMenuPressHandler handler =
      ^(NSString *itemText, NSString *selectedText, NSUInteger selectionStart, NSUInteger selectionEnd) {
        EnrichedMarkdown *strongSelf = weakSelf;
        if (strongSelf)
          [strongSelf emitContextMenuItemPress:itemText
                                  selectedText:selectedText
                                selectionStart:selectionStart
                                  selectionEnd:selectionEnd];
      };
  NSMutableArray<UIAction *> *customActions =
      ENRMBuildContextMenuActions(_contextMenuItemTexts, _contextMenuItemIcons, textView, range, handler);

  NSString *segmentMarkdown = extractMarkdownFromAttributedString(textView.attributedText, range);
  return buildEditMenuForSelection(textView.attributedText, range, segmentMarkdown, _config, suggestedActions,
                                   customActions, _selectionMenuConfig);
}

- (BOOL)textView:(UITextView *)textView
    shouldInteractWithURL:(NSURL *)URL
                  inRange:(NSRange)characterRange
              interaction:(UITextItemInteraction)interaction
{
  if (interaction != UITextItemInteractionPresentActions) {
    return YES;
  }

  NSString *urlString = linkURLAtRange(textView, characterRange);

  if (!urlString || _enableLinkPreview) {
    return YES;
  }

  [self emitLinkLongPress:urlString];
  return NO;
}
#endif

- (BOOL)isAccessibilityElement
{
  return NO;
}

- (NSArray *)accessibilityElements
{
  NSMutableArray *allElements = [NSMutableArray array];
  for (RCTUIView *segment in _segmentViews) {
    if ([segment isKindOfClass:[EnrichedMarkdownInternalText class]]) {
      NSArray *elements = [(EnrichedMarkdownInternalText *)segment accessibilityElements];
      if (elements) {
        [allElements addObjectsFromArray:elements];
      }
    } else if ([segment isKindOfClass:[TableContainerView class]]) {
      NSArray *elements = [(TableContainerView *)segment accessibilityElements];
      if (elements) {
        [allElements addObjectsFromArray:elements];
      }
    }
#if ENRICHED_MARKDOWN_MATH
    else if ([segment isKindOfClass:[ENRMMathContainerView class]]) {
      [allElements addObject:segment];
    }
#endif
  }
  return allElements;
}

- (NSInteger)accessibilityElementCount
{
  return [self accessibilityElements].count;
}

- (id)accessibilityElementAtIndex:(NSInteger)index
{
  NSArray *elements = [self accessibilityElements];
  if (index < 0 || index >= (NSInteger)elements.count) {
    return nil;
  }
  return elements[index];
}

- (NSInteger)indexOfAccessibilityElement:(id)element
{
  return [[self accessibilityElements] indexOfObject:element];
}

#if !TARGET_OS_OSX
- (NSArray<UIAccessibilityCustomRotor *> *)accessibilityCustomRotors
{
  return [MarkdownAccessibilityElementBuilder buildRotorsFromElements:[self accessibilityElements]];
}
#endif

@end
