#import "ENRMMathContainerView.h"
#import "ENRMFeatureFlags.h"
#include <TargetConditionals.h>

#if ENRICHED_MARKDOWN_MATH
#import "PasteboardUtils.h"
@import iosMath;
#if TARGET_OS_OSX
#import "ENRMMenuAction.h"
#endif
#endif

#if ENRICHED_MARKDOWN_MATH

#if !TARGET_OS_OSX
@interface ENRMMathContainerView () <UIContextMenuInteractionDelegate>
@property (nonatomic, strong, readonly) RCTUIScrollView *scrollView;
#else
@interface ENRMMathContainerView ()
#endif
@property (nonatomic, strong, readonly) MTMathUILabel *mathLabel;
@property (nonatomic, copy, readwrite) NSString *cachedLatex;
@end

@implementation ENRMMathContainerView

- (instancetype)initWithConfig:(StyleConfig *)config
{
  self = [super initWithFrame:CGRectZero];
  if (self) {
    _config = config;
    _cachedLatex = @"";

    _mathLabel = [[MTMathUILabel alloc] init];
    _mathLabel.labelMode = kMTMathUILabelModeDisplay;

#if !TARGET_OS_OSX
    _scrollView = [[RCTUIScrollView alloc] init];
    _scrollView.showsVerticalScrollIndicator = NO;
    _scrollView.showsHorizontalScrollIndicator = YES;
    _scrollView.bounces = YES;
    _scrollView.alwaysBounceHorizontal = NO;
    _scrollView.scrollEnabled = NO;
    [self addSubview:_scrollView];
    [_scrollView addSubview:_mathLabel];

    self.isAccessibilityElement = YES;

    UIContextMenuInteraction *contextMenu = [[UIContextMenuInteraction alloc] initWithDelegate:self];
    [self addInteraction:contextMenu];
#else
    // MTMathUILabel sets layer.geometryFlipped=YES for CoreText, but React Native
    // macOS uses isFlipped=YES views. The combination causes rendering artifacts
    // for sibling views. Disable the layer flip — MTMathUILabel's drawRect uses
    // CoreText which respects the CGContext transform, and the label's isFlipped=NO
    // combined with the parent's isFlipped=YES provides the correct coordinate system.
    _mathLabel.layer.geometryFlipped = NO;
    [self addSubview:_mathLabel];
#endif
  }
  return self;
}

- (void)applyLatex:(NSString *)latex
{
  _cachedLatex = [latex copy];

  StyleConfig *config = self.config;

  _mathLabel.latex = latex;
  _mathLabel.fontSize = config.mathFontSize;
  _mathLabel.textColor = config.mathColor;
  _mathLabel.textAlignment = [self mapAlignment:config.mathTextAlign];

  CGFloat padding = config.mathPadding;
#if !TARGET_OS_OSX
  _mathLabel.contentInsets = UIEdgeInsetsMake(padding, padding, padding, padding);
#else
  _mathLabel.contentInsets = NSEdgeInsetsMake(padding, padding, padding, padding);
#endif

  self.backgroundColor = config.mathBackgroundColor;

  [self setNeedsLayout];
}

#if !TARGET_OS_OSX
- (UIContextMenuConfiguration *)contextMenuInteraction:(UIContextMenuInteraction *)interaction
                        configurationForMenuAtLocation:(CGPoint)location
{
  return [UIContextMenuConfiguration
      configurationWithIdentifier:nil
                  previewProvider:nil
                   actionProvider:^UIMenu *(NSArray<UIMenuElement *> *suggestedActions) {
                     UIAction *copyPlainText =
                         [UIAction actionWithTitle:@"Copy"
                                             image:[RCTUIImage systemImageNamed:@"doc.on.doc"]
                                        identifier:nil
                                           handler:^(__kindof UIAction *action) { [self copyLatexToPasteboard]; }];

                     UIAction *copyMarkdown =
                         [UIAction actionWithTitle:@"Copy as Markdown"
                                             image:[RCTUIImage systemImageNamed:@"doc.text"]
                                        identifier:nil
                                           handler:^(__kindof UIAction *action) { [self copyMarkdownToPasteboard]; }];

                     return [UIMenu menuWithTitle:@"" children:@[ copyPlainText, copyMarkdown ]];
                   }];
}
#endif

#if TARGET_OS_OSX
- (NSMenu *)menuForEvent:(NSEvent *)event
{
  NSMenu *menu = [[NSMenu alloc] initWithTitle:@""];
  [menu addItem:ENRMCreateMenuItem(NSLocalizedString(@"Copy", nil), ^{ [self copyLatexToPasteboard]; })];
  [menu addItem:ENRMCreateMenuItem(NSLocalizedString(@"Copy as Markdown", nil), ^{ [self copyMarkdownToPasteboard]; })];
  return menu;
}
#endif

- (void)copyLatexToPasteboard
{
  copyStringToPasteboard(_cachedLatex);
}

- (void)copyMarkdownToPasteboard
{
  copyStringToPasteboard([NSString stringWithFormat:@"$$\n%@\n$$", _cachedLatex]);
}

- (MTTextAlignment)mapAlignment:(NSString *)align
{
  if ([align isEqualToString:@"left"])
    return kMTTextAlignmentLeft;
  if ([align isEqualToString:@"right"])
    return kMTTextAlignmentRight;
  return kMTTextAlignmentCenter;
}

- (CGSize)mathLabelIntrinsicSize
{
#if !TARGET_OS_OSX
  return [_mathLabel sizeThatFits:CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX)];
#else
  return _mathLabel.intrinsicContentSize;
#endif
}

- (CGFloat)measureHeight:(CGFloat)maxWidth
{
  return [self mathLabelIntrinsicSize].height;
}

- (void)layoutSubviews
{
  [super layoutSubviews];

  CGSize intrinsicSize = [self mathLabelIntrinsicSize];
  CGFloat contentWidth = MAX(intrinsicSize.width, self.bounds.size.width);
  CGFloat contentHeight = self.bounds.size.height;

#if !TARGET_OS_OSX
  _scrollView.frame = self.bounds;
  _scrollView.contentSize = CGSizeMake(contentWidth, contentHeight);
  _scrollView.scrollEnabled = (intrinsicSize.width > self.bounds.size.width);
  _mathLabel.frame = CGRectMake(0, 0, contentWidth, contentHeight);
#else
  _mathLabel.frame = CGRectMake(0, 0, contentWidth, contentHeight);
  [_mathLabel setNeedsDisplay:YES];
#endif
}

#if TARGET_OS_OSX
- (void)layout
{
  [super layout];
  [self layoutSubviews];
}
#endif

- (NSString *)accessibilityLabel
{
  return [NSString stringWithFormat:@"Math equation: %@", _cachedLatex];
}

#if !TARGET_OS_OSX
- (UIAccessibilityTraits)accessibilityTraits
{
  return UIAccessibilityTraitStaticText;
}
#endif

@end

#endif
