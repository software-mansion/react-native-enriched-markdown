#import "TableContainerView.h"
#import "AttributedRenderer.h"
#import "ENRMAccessibilityLabels.h"
#import "HTMLGenerator.h"
#import "LinkTapUtils.h"
#import "MarkdownASTNode.h"
#import "MarkdownASTSerializer.h"
#import "ParagraphStyleUtils.h"
#import "PasteboardUtils.h"
#import "RenderContext.h"
#import "StyleConfig.h"
#include <TargetConditionals.h>
#if TARGET_OS_OSX
#import "ENRMMenuAction.h"
#import "ENRMTableGridView.h"
#else
#import "ENRMTableIOSGridView.h"
#endif

@interface TableCellData : NSObject
@property (nonatomic, strong) NSMutableAttributedString *attributedText;
@property (nonatomic, copy) NSString *plainText;
@property (nonatomic, copy) NSString *markdownText;
@property (nonatomic, assign) BOOL isHeader;
@property (nonatomic, assign) NSTextAlignment alignment;
@end

@implementation TableCellData
@end

#if !TARGET_OS_OSX
@interface TableContainerView () <UIContextMenuInteractionDelegate>
@end
#else
@interface TableContainerView ()
@end
#endif

@implementation TableContainerView {
  RCTUIScrollView *_scrollView;
  RCTUIView *_gridContainer;
  NSArray<NSArray<TableCellData *> *> *_rows;
  NSUInteger _colCount;

  NSMutableArray<NSNumber *> *_colWidths;
  NSMutableArray<NSNumber *> *_rowHeights;
  CGFloat _totalTableWidth;
  CGFloat _totalTableHeight;
  CGFloat _borderWidth;

  NSString *_cachedMarkdown;

  NSArray *_cachedAccessibilityElements;
}

- (instancetype)initWithConfig:(StyleConfig *)config
{
  self = [super initWithFrame:CGRectZero];
  if (self) {
    _config = config;
    _borderWidth = config.tableBorderWidth;
    _allowFontScaling = YES;
    _maxFontSizeMultiplier = 0;
    _enableLinkPreview = YES;
    _writingDirectionMode = ENRMWritingDirectionModeFirstStrong;
    _resolvedLayoutDirection = NSWritingDirectionLeftToRight;
    [self setupScrollView];
  }
  return self;
}

- (void)setupScrollView
{
  _scrollView = [[RCTUIScrollView alloc] init];
  _scrollView.showsVerticalScrollIndicator = NO;
  _scrollView.showsHorizontalScrollIndicator = YES;
#if !TARGET_OS_OSX
  _scrollView.bounces = YES;
  _scrollView.alwaysBounceHorizontal = NO;
  _scrollView.isAccessibilityElement = NO;
  _scrollView.accessibilityElementsHidden = YES;
#endif
  [self addSubview:_scrollView];

#if TARGET_OS_OSX
  // On macOS, use ENRMTableGridView as the NSScrollView documentView so that the
  // coordinate system is managed correctly and the entire table is drawn in
  // a single drawRect: pass (no subview / layer compositing issues).
  ENRMTableGridView *gridView = [[ENRMTableGridView alloc] initWithFrame:CGRectZero];
  __weak TableContainerView *weakSelf = self;
  gridView.menuProvider = ^NSMenu * {
    TableContainerView *strongSelf = weakSelf;
    if (!strongSelf)
      return nil;
    NSMenu *menu = [[NSMenu alloc] initWithTitle:@""];
    [menu addItem:ENRMCreateMenuItem(strongSelf.copyLabel, ^{ [strongSelf copyTableToPasteboard]; })];
    [menu addItem:ENRMCreateMenuItem(strongSelf.copyAsMarkdownLabel, ^{ [strongSelf copyMarkdownToPasteboard]; })];
    return menu;
  };
  _gridContainer = gridView;
  [(NSScrollView *)_scrollView setDocumentView:_gridContainer];
#else
  ENRMTableIOSGridView *iosGridView = [[ENRMTableIOSGridView alloc] initWithFrame:CGRectZero];
  __weak TableContainerView *weakSelf = self;
  iosGridView.onLinkTap = ^(NSString *url) {
    TableContainerView *strongSelf = weakSelf;
    if (strongSelf && strongSelf.onLinkPress)
      strongSelf.onLinkPress(url);
  };
  iosGridView.onLinkLongTap = ^(NSString *url) {
    TableContainerView *strongSelf = weakSelf;
    if (strongSelf && strongSelf.onLinkLongPress)
      strongSelf.onLinkLongPress(url);
  };
  _gridContainer = iosGridView;
  [_scrollView addSubview:_gridContainer];
  UIContextMenuInteraction *contextMenu = [[UIContextMenuInteraction alloc] initWithDelegate:self];
  [_gridContainer addInteraction:contextMenu];
#endif
}

- (StyleConfig *)cellConfigForHeader:(BOOL)isHeader
{
  StyleConfig *cellConfig = [self.config copy];

  [cellConfig setParagraphFontSize:self.config.tableFontSize];
  NSString *headerFamily =
      self.config.tableHeaderFontFamily.length > 0 ? self.config.tableHeaderFontFamily : self.config.tableFontFamily;
  [cellConfig setParagraphFontFamily:isHeader ? headerFamily : self.config.tableFontFamily];
  [cellConfig setParagraphFontWeight:isHeader ? @"bold" : self.config.tableFontWeight];
  [cellConfig setParagraphColor:isHeader ? self.config.tableHeaderTextColor : self.config.tableColor];
  [cellConfig setParagraphLineHeight:self.config.tableLineHeight];

  [cellConfig setParagraphMarginTop:0];
  [cellConfig setParagraphMarginBottom:0];

  return cellConfig;
}

- (NSMutableAttributedString *)renderCellNode:(MarkdownASTNode *)cellNode
                                     isHeader:(BOOL)isHeader
                                   cellConfig:(StyleConfig *)cellConfig
                                    alignment:(NSTextAlignment)alignment
{

  MarkdownASTNode *temporaryRoot = [[MarkdownASTNode alloc] initWithType:MarkdownNodeTypeDocument];
  for (MarkdownASTNode *child in cellNode.children) {
    [temporaryRoot addChild:child];
  }

  AttributedRenderer *renderer = [[AttributedRenderer alloc] initWithConfig:cellConfig];
  RenderContext *context = [RenderContext new];
  context.allowFontScaling = self.allowFontScaling;
  context.maxFontSizeMultiplier = self.maxFontSizeMultiplier;

  NSMutableAttributedString *attributedText = [renderer renderRoot:temporaryRoot context:context];

  [context applyLinkAttributesToString:attributedText];

  ENRMApplyWritingDirectionMode(attributedText, _writingDirectionMode, _resolvedLayoutDirection);

  if (alignment != NSTextAlignmentLeft && attributedText.length > 0) {
    NSRange fullRange = NSMakeRange(0, attributedText.length);
    [attributedText
        enumerateAttribute:NSParagraphStyleAttributeName
                   inRange:fullRange
                   options:0
                usingBlock:^(NSParagraphStyle *paragraphStyle, NSRange range, BOOL *stop) {
                  NSMutableParagraphStyle *mutableStyle =
                      paragraphStyle ? [paragraphStyle mutableCopy] : [[NSMutableParagraphStyle alloc] init];
                  mutableStyle.alignment = alignment;
                  [attributedText addAttribute:NSParagraphStyleAttributeName value:mutableStyle range:range];
                }];
  }

  return attributedText;
}

- (NSString *)extractPlainTextFromNode:(MarkdownASTNode *)node
{
  if (!node)
    return @"";
  NSMutableString *buffer = [node.content mutableCopy] ?: [NSMutableString string];
  for (MarkdownASTNode *child in node.children) {
    [buffer appendString:[self extractPlainTextFromNode:child]];
  }
  return [buffer copy];
}

- (NSUInteger)rowCount
{
  return _rows.count;
}

#if !TARGET_OS_OSX
- (void)animateNewRowsFromPreviousCount:(NSUInteger)previousRowCount duration:(NSTimeInterval)duration
{
  if (self.rowCount <= previousRowCount) {
    return;
  }
  [(ENRMTableIOSGridView *)_gridContainer fadeInRowsFrom:previousRowCount duration:duration];
}
#else
- (void)animateNewRowsFromPreviousCount:(NSUInteger)previousRowCount duration:(NSTimeInterval)duration
{
  // No-op on macOS
}
#endif

- (void)applyTableNode:(MarkdownASTNode *)tableNode
{
  [[_gridContainer subviews] makeObjectsPerformSelector:@selector(removeFromSuperview)];

  StyleConfig *headerCellConfig = [self cellConfigForHeader:YES];
  StyleConfig *bodyCellConfig = [self cellConfigForHeader:NO];

  NSMutableArray *allRows = [NSMutableArray array];
  _colCount = 0;

  for (MarkdownASTNode *section in tableNode.children) {
    BOOL isSectionHead = (section.type == MarkdownNodeTypeTableHead);

    for (MarkdownASTNode *rowNode in section.children) {
      if (rowNode.type != MarkdownNodeTypeTableRow)
        continue;

      NSMutableArray<TableCellData *> *rowCells = [NSMutableArray array];
      for (MarkdownASTNode *cellNode in rowNode.children) {
        TableCellData *cell = [[TableCellData alloc] init];
        cell.isHeader = isSectionHead || (cellNode.type == MarkdownNodeTypeTableHeaderCell);
        cell.alignment = [self textAlignmentFromString:cellNode.attributes[@"align"]];
        cell.plainText = [self extractPlainTextFromNode:cellNode];
        cell.markdownText = markdownFromASTNodeChildren(cellNode);

        StyleConfig *cellConfig = cell.isHeader ? headerCellConfig : bodyCellConfig;
        cell.attributedText = [self renderCellNode:cellNode
                                          isHeader:cell.isHeader
                                        cellConfig:cellConfig
                                         alignment:cell.alignment];
        [rowCells addObject:cell];
      }
      _colCount = MAX(_colCount, rowCells.count);
      [allRows addObject:rowCells];
    }
  }

  _rows = [allRows copy];
  _cachedMarkdown = [self buildMarkdownFromRows];
  _cachedAccessibilityElements = nil;
  [self computeLayout];
  [self renderGrid];
}

- (NSTextAlignment)textAlignmentFromString:(NSString *)align
{
  if ([align isEqualToString:@"center"])
    return NSTextAlignmentCenter;
  if ([align isEqualToString:@"right"])
    return NSTextAlignmentRight;
  return NSTextAlignmentLeft;
}

- (void)computeLayout
{
  // TODO: Consider making minColumnWidth / maxColumnWidth configurable via style props
  const CGFloat minimumColumnWidth = 60.0;
  const CGFloat maximumColumnWidth = 300.0;
  const CGFloat horizontalPadding = self.config.tableCellPaddingHorizontal * 2;
  const CGFloat verticalPadding = self.config.tableCellPaddingVertical * 2;

  _colWidths = [NSMutableArray arrayWithCapacity:_colCount];
  for (NSUInteger i = 0; i < _colCount; i++)
    [_colWidths addObject:@0];

  for (NSArray<TableCellData *> *row in _rows) {
    for (NSUInteger column = 0; column < row.count; column++) {
      CGRect boundingRect = [row[column].attributedText
          boundingRectWithSize:CGSizeMake(maximumColumnWidth, CGFLOAT_MAX)
                       options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading
                       context:nil];
      CGFloat width = MIN(MAX(ceil(boundingRect.size.width) + horizontalPadding, minimumColumnWidth),
                          maximumColumnWidth + horizontalPadding);
      if (width > [_colWidths[column] doubleValue])
        _colWidths[column] = @(width);
    }
  }

  _rowHeights = [NSMutableArray arrayWithCapacity:_rows.count];
  for (NSArray<TableCellData *> *row in _rows) {
    CGFloat maxHeight = 0;
    for (NSUInteger column = 0; column < row.count; column++) {
      CGFloat availableWidth = [_colWidths[column] doubleValue] - horizontalPadding;
      CGRect boundingRect = [row[column].attributedText
          boundingRectWithSize:CGSizeMake(availableWidth, CGFLOAT_MAX)
                       options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading
                       context:nil];
      maxHeight = MAX(maxHeight, ceil(boundingRect.size.height) + verticalPadding);
    }
    [_rowHeights addObject:@(maxHeight)];
  }

  _totalTableWidth = [[_colWidths valueForKeyPath:@"@sum.self"] doubleValue] + _borderWidth;
  _totalTableHeight = [[_rowHeights valueForKeyPath:@"@sum.self"] doubleValue] + _borderWidth;
}

- (void)renderGrid
{
#if !TARGET_OS_OSX
  [self renderGridIOS];
#else
  [self renderGridMacOS];
#endif
}

- (RCTUIColor *)backgroundColorForRowIsHeader:(BOOL)isHeader bodyRowIndex:(NSUInteger)bodyRowIndex
{
  if (isHeader) {
    return self.config.tableHeaderBackgroundColor;
  }
  return (bodyRowIndex % 2 == 0) ? self.config.tableRowEvenBackgroundColor : self.config.tableRowOddBackgroundColor;
}

- (NSArray<NSAttributedString *> *)attributedTextsForRow:(NSArray<TableCellData *> *)rowCells
{
  NSMutableArray<NSAttributedString *> *cellTexts = [NSMutableArray arrayWithCapacity:_colCount];
  for (NSUInteger columnIndex = 0; columnIndex < _colCount; columnIndex++) {
    NSAttributedString *text = (columnIndex < rowCells.count) ? rowCells[columnIndex].attributedText : nil;
    [cellTexts addObject:text ?: [[NSAttributedString alloc] init]];
  }
  return [cellTexts copy];
}

#if TARGET_OS_OSX
- (void)renderGridMacOS
{
  _gridContainer.frame = CGRectMake(0, 0, _totalTableWidth, _totalTableHeight);

  NSUInteger bodyRowIndex = 0;
  NSMutableArray<ENRMMacOSTableRowData *> *rowDataArray = [NSMutableArray arrayWithCapacity:_rows.count];

  for (NSArray<TableCellData *> *rowCells in _rows) {
    BOOL isHeaderRow = (rowCells.count > 0 && rowCells.firstObject.isHeader);

    ENRMMacOSTableRowData *rowData = [[ENRMMacOSTableRowData alloc] init];
    rowData.backgroundColor = [self backgroundColorForRowIsHeader:isHeaderRow bodyRowIndex:bodyRowIndex];
    rowData.cellTexts = [self attributedTextsForRow:rowCells];
    [rowDataArray addObject:rowData];

    if (!isHeaderRow) {
      bodyRowIndex++;
    }
  }

  ENRMTableGridView *gridView = (ENRMTableGridView *)_gridContainer;
  [gridView updateWithRows:[rowDataArray copy]
               columnWidths:_colWidths
                 rowHeights:_rowHeights
                borderColor:self.config.tableBorderColor
                borderWidth:_borderWidth
      horizontalCellPadding:self.config.tableCellPaddingHorizontal
        verticalCellPadding:self.config.tableCellPaddingVertical
               cornerRadius:self.config.tableBorderRadius];
}

#else

- (void)renderGridIOS
{
  _gridContainer.frame = CGRectMake(0, 0, _totalTableWidth, _totalTableHeight);
  _gridContainer.layer.cornerRadius = self.config.tableBorderRadius;
  _gridContainer.layer.masksToBounds = YES;

  NSUInteger bodyRowIndex = 0;
  NSMutableArray<ENRMTableIOSRowData *> *rowDataArray = [NSMutableArray arrayWithCapacity:_rows.count];

  for (NSArray<TableCellData *> *rowCells in _rows) {
    BOOL isHeaderRow = (rowCells.count > 0 && rowCells.firstObject.isHeader);

    ENRMTableIOSRowData *rowData = [[ENRMTableIOSRowData alloc] init];
    rowData.backgroundColor = [self backgroundColorForRowIsHeader:isHeaderRow bodyRowIndex:bodyRowIndex];
    rowData.cellTexts = [self attributedTextsForRow:rowCells];
    [rowDataArray addObject:rowData];

    if (!isHeaderRow) {
      bodyRowIndex++;
    }
  }

  ENRMTableIOSGridView *gridView = (ENRMTableIOSGridView *)_gridContainer;
  [gridView updateWithRows:[rowDataArray copy]
               columnWidths:_colWidths
                 rowHeights:_rowHeights
                borderColor:self.config.tableBorderColor
                borderWidth:_borderWidth
      horizontalCellPadding:self.config.tableCellPaddingHorizontal
        verticalCellPadding:self.config.tableCellPaddingVertical
               cornerRadius:self.config.tableBorderRadius];
}
#endif

#if !TARGET_OS_OSX
- (UIContextMenuConfiguration *)contextMenuInteraction:(UIContextMenuInteraction *)interaction
                        configurationForMenuAtLocation:(CGPoint)location
{
  return [UIContextMenuConfiguration
      configurationWithIdentifier:nil
                  previewProvider:nil
                   actionProvider:^UIMenu *(NSArray<UIMenuElement *> *suggestedActions) {
                     UIAction *copyMarkdown =
                         [UIAction actionWithTitle:self.copyAsMarkdownLabel
                                             image:[RCTUIImage systemImageNamed:@"doc.text"]
                                        identifier:nil
                                           handler:^(__kindof UIAction *action) { [self copyMarkdownToPasteboard]; }];

                     UIAction *copyPlainText =
                         [UIAction actionWithTitle:self.copyLabel
                                             image:[RCTUIImage systemImageNamed:@"doc.on.doc"]
                                        identifier:nil
                                           handler:^(__kindof UIAction *action) { [self copyTableToPasteboard]; }];

                     return [UIMenu menuWithTitle:@"" children:@[ copyPlainText, copyMarkdown ]];
                   }];
}
#endif // !TARGET_OS_OSX

- (void)copyMarkdownToPasteboard
{
  if (_cachedMarkdown.length > 0) {
    copyStringToPasteboard(_cachedMarkdown);
  }
}

- (void)copyTableToPasteboard
{
  NSString *plainText = [self buildPlainTextFromRows];
  if (plainText.length == 0)
    return;

  NSMutableDictionary *items = [NSMutableDictionary dictionary];
  items[kUTIPlainText] = plainText;

  if (_cachedMarkdown.length > 0) {
    items[kUTIMarkdown] = _cachedMarkdown;
  }

  NSString *html = generateTableHTML([self rowDictionariesForHTML], self.config);
  if (html.length > 0) {
    NSData *htmlData = [html dataUsingEncoding:NSUTF8StringEncoding];
    if (htmlData)
      items[kUTIHTML] = htmlData;
  }

  copyItemsToPasteboard(items);
}

- (NSString *)buildMarkdownFromRows
{
  if (_rows.count == 0 || _colCount == 0)
    return @"";

  NSMutableString *markdown = [NSMutableString string];
  BOOL headerSeparatorAdded = NO;

  for (NSArray<TableCellData *> *row in _rows) {
    NSMutableArray<NSString *> *cellStrings = [NSMutableArray arrayWithCapacity:_colCount];

    for (NSUInteger column = 0; column < _colCount; column++) {
      NSString *cellMarkdown = (column < row.count) ? (row[column].markdownText ?: @"") : @"";
      [cellStrings addObject:cellMarkdown];
    }

    [markdown appendFormat:@"| %@ |\n", [cellStrings componentsJoinedByString:@" | "]];

    if (!headerSeparatorAdded && row.count > 0 && row.firstObject.isHeader) {
      NSMutableArray<NSString *> *separators = [NSMutableArray arrayWithCapacity:_colCount];

      for (NSUInteger column = 0; column < _colCount; column++) {
        NSTextAlignment columnAlignment = (column < row.count) ? row[column].alignment : NSTextAlignmentLeft;

        switch (columnAlignment) {
          case NSTextAlignmentCenter:
            [separators addObject:@":---:"];
            break;
          case NSTextAlignmentRight:
            [separators addObject:@"---:"];
            break;
          default:
            [separators addObject:@"---"];
            break;
        }
      }

      [markdown appendFormat:@"| %@ |\n", [separators componentsJoinedByString:@" | "]];
      headerSeparatorAdded = YES;
    }
  }

  return [markdown copy];
}

- (NSString *)buildPlainTextFromRows
{
  if (_rows.count == 0)
    return @"";

  NSMutableString *result = [NSMutableString string];

  for (NSArray<TableCellData *> *row in _rows) {
    NSMutableArray<NSString *> *rowContent = [NSMutableArray arrayWithCapacity:row.count];

    for (TableCellData *cell in row) {
      [rowContent addObject:cell.plainText ?: @""];
    }

    [result appendFormat:@"%@\n", [rowContent componentsJoinedByString:@"\t"]];
  }

  return [result copy];
}

- (NSArray<NSArray<NSDictionary *> *> *)rowDictionariesForHTML
{
  NSMutableArray *rowsResult = [NSMutableArray arrayWithCapacity:_rows.count];

  for (NSArray<TableCellData *> *cellDataRow in _rows) {
    NSMutableArray *rowDictionaries = [NSMutableArray arrayWithCapacity:cellDataRow.count];

    for (TableCellData *cell in cellDataRow) {
      NSAttributedString *text = cell.attributedText ?: [[NSAttributedString alloc] init];

      NSDictionary *cellDict =
          @{@"attributedText" : text, @"isHeader" : @(cell.isHeader), @"alignment" : @(cell.alignment)};

      [rowDictionaries addObject:cellDict];
    }

    [rowsResult addObject:[rowDictionaries copy]];
  }

  return [rowsResult copy];
}

- (CGFloat)measureHeight:(CGFloat)maxWidth
{
  if (_rows.count == 0)
    return 0;
  if (_rowHeights.count == 0)
    [self computeLayout];
  return _totalTableHeight;
}

- (void)layoutSubviews
{
  [super layoutSubviews];
  _scrollView.frame = self.bounds;
#if !TARGET_OS_OSX
  CGFloat overflow = MAX(self.config.tableHorizontalOverflow, 0);
  CGFloat containerWidth = self.bounds.size.width;
  CGFloat originalWidth = containerWidth - overflow * 2;
  BOOL needsEdgeToEdge = (overflow > 0 && _totalTableWidth > originalWidth);

  if (needsEdgeToEdge && _totalTableWidth > containerWidth) {
    UIEdgeInsets inset = UIEdgeInsetsMake(0, overflow, 0, overflow);
    if (!UIEdgeInsetsEqualToEdgeInsets(_scrollView.contentInset, inset)) {
      _scrollView.contentInset = inset;
      _scrollView.contentOffset = CGPointMake(-overflow, 0);
    }
    _scrollView.contentSize = CGSizeMake(_totalTableWidth, _totalTableHeight);
    _scrollView.scrollEnabled = YES;
    _gridContainer.frame = CGRectMake(0, 0, _totalTableWidth, _totalTableHeight);
  } else if (overflow > 0) {
    _scrollView.contentInset = UIEdgeInsetsZero;
    _scrollView.contentOffset = CGPointZero;
    _scrollView.contentSize = CGSizeMake(containerWidth, _totalTableHeight);
    _scrollView.scrollEnabled = NO;
    _gridContainer.frame = CGRectMake(overflow, 0, _totalTableWidth, _totalTableHeight);
  } else {
    _scrollView.contentInset = UIEdgeInsetsZero;
    _scrollView.contentOffset = CGPointZero;
    _scrollView.contentSize = CGSizeMake(MAX(_totalTableWidth, containerWidth), _totalTableHeight);
    _scrollView.scrollEnabled = (_totalTableWidth > containerWidth);
    _gridContainer.frame = CGRectMake(0, 0, _totalTableWidth, _totalTableHeight);
  }
#else
  CGFloat overflow = MAX(self.config.tableHorizontalOverflow, 0);
  CGFloat containerWidth = self.bounds.size.width;
  BOOL needsEdgeToEdge = (overflow > 0 && _totalTableWidth > containerWidth);

  if (needsEdgeToEdge) {
    _gridContainer.frame = CGRectMake(0, 0, _totalTableWidth, _totalTableHeight);
  } else if (overflow > 0) {
    _gridContainer.frame = CGRectMake(overflow, 0, _totalTableWidth, _totalTableHeight);
  } else if (_totalTableWidth > 0 && _totalTableHeight > 0) {
    _gridContainer.frame = CGRectMake(0, 0, _totalTableWidth, _totalTableHeight);
  }
#endif
}

- (BOOL)isAccessibilityElement
{
  return NO;
}

- (void)setAccessibilityLabels:(ENRMAccessibilityLabels *)labels
{
  if (_accessibilityLabels == labels)
    return;
  _accessibilityLabels = labels;
  _cachedAccessibilityElements = nil;
}

- (NSArray *)accessibilityElements
{
  if (_rows.count == 0)
    return nil;
  if (_cachedAccessibilityElements != nil)
    return _cachedAccessibilityElements;

  NSMutableArray *elements = [NSMutableArray array];
  CGFloat yOffset = 0;

  for (NSUInteger rowIndex = 0; rowIndex < _rows.count; rowIndex++) {
    NSArray<TableCellData *> *row = _rows[rowIndex];
    CGFloat rowHeight = [_rowHeights[rowIndex] doubleValue];

    NSMutableArray *cellTexts = [NSMutableArray array];
    for (TableCellData *cell in row) {
      if (cell.plainText.length > 0)
        [cellTexts addObject:cell.plainText];
    }

    if (cellTexts.count > 0) {
#if !TARGET_OS_OSX
      UIAccessibilityElement *element = [[UIAccessibilityElement alloc] initWithAccessibilityContainer:self];
      NSString *withN = [_accessibilityLabels.tableRow
          stringByReplacingOccurrencesOfString:@"{n}"
                                    withString:[NSString stringWithFormat:@"%lu", (unsigned long)(rowIndex + 1)]];
      element.accessibilityLabel =
          [withN stringByReplacingOccurrencesOfString:@"{content}"
                                           withString:[cellTexts componentsJoinedByString:@", "]];
      element.accessibilityFrameInContainerSpace = CGRectMake(0, yOffset, _totalTableWidth, rowHeight);
      element.accessibilityTraits =
          row.firstObject.isHeader ? UIAccessibilityTraitHeader : UIAccessibilityTraitStaticText;
      [elements addObject:element];
#else
      // TODO: Implement macOS VoiceOver support for table rows using NSAccessibility.
      // ENRMTableGridView draws the entire table in a single drawRect: pass, so AppKit
      // cannot discover cells automatically. Needs accessibilityRole, accessibilityChildren
      // (NSAccessibilityRowRole per row, NSAccessibilityCellRole per cell), and
      // accessibilityLabel populated from plainText on ENRMTableGridView.
#endif
    }
    yOffset += rowHeight;
  }
  _cachedAccessibilityElements = elements;
  return elements;
}

@end
