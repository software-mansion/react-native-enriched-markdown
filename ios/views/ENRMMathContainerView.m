#import "ENRMMathContainerView.h"
#import "ENRMFeatureFlags.h"
#include <TargetConditionals.h>

#if ENRICHED_MARKDOWN_MATH
#import "ENRMMathEngine.h"
#import "PasteboardUtils.h"
#if TARGET_OS_OSX
#import "ENRMMenuAction.h"
#endif
#endif

#if ENRICHED_MARKDOWN_MATH

#pragma mark - Inner rendering view

/// Engine-agnostic view that paints a single laid-out formula. The block
/// container places one inside its scroll view (UIKit) or directly as a
/// subview (AppKit) and resizes it to the formula's intrinsic content size.
@interface ENRMMathRenderingView : RCTUIView
@property (nonatomic, strong, nullable) id<ENRMLaidOutMath> layout;
@property (nonatomic, assign) UIEdgeInsets contentInsets;
@end

@implementation ENRMMathRenderingView

- (instancetype)initWithFrame:(CGRect)frame
{
  self = [super initWithFrame:frame];
  if (self) {
    self.backgroundColor = [RCTUIColor clearColor];
    self.opaque = NO;
#if !TARGET_OS_OSX
    self.contentMode = UIViewContentModeRedraw;
#endif
  }
  return self;
}

#if TARGET_OS_OSX
- (BOOL)isFlipped
{
  // Match the rest of the React Native macOS view tree. `drawRect:` then
  // hands us a top-left origin context — exactly what the engine
  // `drawInContext:` contract expects, so no further flip is needed.
  return YES;
}
#endif

- (CGSize)intrinsicContentSize
{
  if (!_layout) {
    return CGSizeZero;
  }
  return CGSizeMake(_layout.width + _contentInsets.left + _contentInsets.right,
                    _layout.ascent + _layout.descent + _contentInsets.top + _contentInsets.bottom);
}

#if !TARGET_OS_OSX
- (CGSize)sizeThatFits:(CGSize)size
{
  return [self intrinsicContentSize];
}
#endif

- (void)setLayout:(id<ENRMLaidOutMath>)layout
{
  _layout = layout;
  [self invalidateIntrinsicContentSize];
#if !TARGET_OS_OSX
  [self setNeedsDisplay];
#else
  [self setNeedsDisplay:YES];
#endif
}

- (void)setContentInsets:(UIEdgeInsets)contentInsets
{
  _contentInsets = contentInsets;
  [self invalidateIntrinsicContentSize];
#if !TARGET_OS_OSX
  [self setNeedsDisplay];
#else
  [self setNeedsDisplay:YES];
#endif
}

- (void)drawRect:(CGRect)rect
{
  if (!_layout) {
    return;
  }

#if !TARGET_OS_OSX
  CGContextRef ctx = UIGraphicsGetCurrentContext();
#else
  CGContextRef ctx = [[NSGraphicsContext currentContext] CGContext];
#endif
  if (!ctx) {
    return;
  }

  CGContextSaveGState(ctx);
  CGContextTranslateCTM(ctx, _contentInsets.left, _contentInsets.top);
  [_layout drawInContext:ctx];
  CGContextRestoreGState(ctx);
}

@end

#pragma mark - Container view

#if !TARGET_OS_OSX
@interface ENRMMathContainerView () <UIContextMenuInteractionDelegate>
@property (nonatomic, strong, readonly) RCTUIScrollView *scrollView;
#else
@interface ENRMMathContainerView ()
#endif
@property (nonatomic, strong, readonly) ENRMMathRenderingView *mathView;
@property (nonatomic, copy, readwrite) NSString *cachedLatex;
@end

@implementation ENRMMathContainerView

- (instancetype)initWithConfig:(StyleConfig *)config
{
  self = [super initWithFrame:CGRectZero];
  if (self) {
    _config = config;
    _cachedLatex = @"";

    _mathView = [[ENRMMathRenderingView alloc] init];

#if !TARGET_OS_OSX
    _scrollView = [[RCTUIScrollView alloc] init];
    _scrollView.showsVerticalScrollIndicator = NO;
    _scrollView.showsHorizontalScrollIndicator = YES;
    _scrollView.bounces = YES;
    _scrollView.alwaysBounceHorizontal = NO;
    _scrollView.scrollEnabled = NO;
    [self addSubview:_scrollView];
    [_scrollView addSubview:_mathView];

    self.isAccessibilityElement = YES;

    UIContextMenuInteraction *contextMenu = [[UIContextMenuInteraction alloc] initWithDelegate:self];
    [self addInteraction:contextMenu];
#else
    [self addSubview:_mathView];
#endif
  }
  return self;
}

- (void)applyLatex:(NSString *)latex
{
  _cachedLatex = [latex copy];

  StyleConfig *config = self.config;
  CGFloat padding = config.mathPadding;

  _mathView.contentInsets = UIEdgeInsetsMake(padding, padding, padding, padding);
  _mathView.layout = [ENRMSharedMathEngine() layoutLatex:latex
                                             displayMode:YES
                                                fontSize:config.mathFontSize
                                                   color:config.mathColor];

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

- (CGFloat)measureHeight:(CGFloat)maxWidth
{
  return [_mathView intrinsicContentSize].height;
}

- (void)layoutSubviews
{
  [super layoutSubviews];

  CGSize intrinsicSize = [_mathView intrinsicContentSize];
  CGFloat hostWidth = self.bounds.size.width;
  CGFloat contentWidth = MAX(intrinsicSize.width, hostWidth);
  CGFloat contentHeight = self.bounds.size.height;

  CGFloat xOffset = 0;
  if (intrinsicSize.width < hostWidth) {
    NSString *align = self.config.mathTextAlign;
    if ([align isEqualToString:@"right"]) {
      xOffset = hostWidth - intrinsicSize.width;
    } else if (![align isEqualToString:@"left"]) {
      xOffset = (hostWidth - intrinsicSize.width) / 2.0;
    }
  }

#if !TARGET_OS_OSX
  _scrollView.frame = self.bounds;
  _scrollView.contentSize = CGSizeMake(contentWidth, contentHeight);
  _scrollView.scrollEnabled = (intrinsicSize.width > hostWidth);
  _mathView.frame = CGRectMake(xOffset, 0, intrinsicSize.width, intrinsicSize.height);
#else
  _mathView.frame = CGRectMake(xOffset, 0, intrinsicSize.width, intrinsicSize.height);
  [_mathView setNeedsDisplay:YES];
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
