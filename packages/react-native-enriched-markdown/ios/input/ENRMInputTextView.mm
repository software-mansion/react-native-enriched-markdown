#import "ENRMInputTextView.h"
#import "ENRMParseResult.h"
#import "EnrichedMarkdownTextInput.h"
#if TARGET_OS_OSX
#import "EnrichedMarkdownTextInput+Internal.h"
#endif

static NSString *const kENRMMarkdownPasteboardType = @"com.swmansion.enriched-markdown.markdown";

#if !TARGET_OS_OSX

#import <UIKit/UIKit.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

@implementation ENRMInputTextView

- (void)copy:(id)sender
{
  NSRange selection = self.selectedRange;
  if (selection.length == 0) {
    return;
  }

  NSString *plainText = [self.text substringWithRange:selection];
  NSString *markdown = [self.markdownTextInput markdownForSelectedRange];

  UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
  NSMutableDictionary *items = [NSMutableDictionary dictionary];
  items[UTTypePlainText.identifier] = plainText;
  if (markdown.length > 0) {
    items[kENRMMarkdownPasteboardType] = markdown;
  }
  pasteboard.items = @[ items ];
}

- (void)cut:(id)sender
{
  [self copy:sender];
  [self.markdownTextInput replaceSelectedTextWithParseResult:[ENRMParseResult resultWithPlainText:@""
                                                                                 formattingRanges:@[]
                                                                                     imageEntries:@[]]];
}

- (void)paste:(id)sender
{
  UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];

  NSMutableArray<NSDictionary *> *foundImages = [self extractImagesFromPasteboard:pasteboard];
  if (foundImages.count > 0 && self.markdownTextInput != nil) {
    [self.markdownTextInput emitOnPasteImagesEvent:foundImages];
    return;
  }

  NSString *markdown = nil;
  id markdownValue = [pasteboard valueForPasteboardType:kENRMMarkdownPasteboardType];
  if ([markdownValue isKindOfClass:[NSString class]]) {
    markdown = markdownValue;
  } else if ([markdownValue isKindOfClass:[NSData class]]) {
    markdown = [[NSString alloc] initWithData:markdownValue encoding:NSUTF8StringEncoding];
  }

  if (markdown.length > 0 && self.markdownTextInput != nil) {
    [self.markdownTextInput pasteMarkdown:markdown];
    return;
  }

  NSString *plainText = pasteboard.string;
  if (plainText.length > 0) {
    [self replaceRange:self.selectedTextRange withText:plainText];
  }
}

static NSDictionary<NSString *, NSString *> *fileInfoForUTType(NSString *type)
{
  static NSDictionary<NSString *, NSArray<NSString *> *> *mapping;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    mapping = @{
      UTTypeJPEG.identifier : @[ @"jpg", @"image/jpeg" ],
      UTTypePNG.identifier : @[ @"png", @"image/png" ],
      UTTypeGIF.identifier : @[ @"gif", @"image/gif" ],
      UTTypeHEIC.identifier : @[ @"heic", @"image/heic" ],
      UTTypeWebP.identifier : @[ @"webp", @"image/webp" ],
      UTTypeTIFF.identifier : @[ @"tiff", @"image/tiff" ],
    };
  });
  NSArray<NSString *> *info = mapping[type];
  if (!info)
    return nil;
  return @{@"ext" : info[0], @"mimeType" : info[1]};
}

static NSData *imageDataFromItem(NSDictionary<NSString *, id> *item, NSString *type, UIPasteboard *pasteboard)
{
  if ([type isEqual:UTTypeWebP.identifier] || [type isEqual:UTTypeGIF.identifier]) {
    return [pasteboard dataForPasteboardType:type];
  }

  id value = item[type];
  if ([value isKindOfClass:[NSData class]]) {
    return (NSData *)value;
  }
  if ([value isKindOfClass:[UIImage class]]) {
    UIImage *img = (UIImage *)value;
    return [type isEqual:UTTypePNG.identifier] ? UIImagePNGRepresentation(img) : UIImageJPEGRepresentation(img, 1.0);
  }
  return nil;
}

static NSDictionary *saveImageToTempFile(NSData *data, NSString *ext, NSString *mimeType)
{
  UIImage *image = [UIImage imageWithData:data];
  if (!image)
    return nil;

  NSString *fileName = [NSString stringWithFormat:@"%@.%@", [NSUUID UUID].UUIDString, ext];
  NSString *filePath = [NSTemporaryDirectory() stringByAppendingPathComponent:fileName];

  if (![data writeToFile:filePath atomically:YES])
    return nil;

  return @{
    @"uri" : [NSURL fileURLWithPath:filePath].absoluteString,
    @"type" : mimeType,
    @"width" : @(image.size.width),
    @"height" : @(image.size.height),
  };
}

- (NSMutableArray<NSDictionary *> *)extractImagesFromPasteboard:(UIPasteboard *)pasteboard
{
  NSMutableArray<NSDictionary *> *foundImages = [NSMutableArray array];

  for (NSDictionary<NSString *, id> *item in pasteboard.items) {
    for (NSString *type in item.allKeys) {
      NSDictionary<NSString *, NSString *> *info = fileInfoForUTType(type);
      if (!info)
        continue;

      NSData *data = imageDataFromItem(item, type, pasteboard);
      if (!data)
        continue;

      NSDictionary *entry = saveImageToTempFile(data, info[@"ext"], info[@"mimeType"]);
      if (entry) {
        [foundImages addObject:entry];
        break;
      }
    }
  }

  return foundImages;
}

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender
{
  if (action == @selector(paste:)) {
    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
    if (pasteboard.hasStrings || pasteboard.hasImages ||
        [pasteboard containsPasteboardTypes:@[ kENRMMarkdownPasteboardType ]]) {
      return YES;
    }
  }
  return [super canPerformAction:action withSender:sender];
}

- (void)layoutSubviews
{
  [super layoutSubviews];
  if (self.markdownTextInput != nil) {
    [self.markdownTextInput scheduleRelayoutIfNeeded];
  }
}

@end

#else // TARGET_OS_OSX

@implementation ENRMInputTextView

- (void)copy:(id)sender
{
  NSRange selection = self.selectedRange;
  if (selection.length == 0) {
    return;
  }

  NSString *plainText = [self.string substringWithRange:selection];
  NSString *markdown = [self.markdownTextInput markdownForSelectedRange];

  NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
  [pasteboard clearContents];
  NSMutableArray *types = [NSMutableArray arrayWithObject:NSPasteboardTypeString];
  if (markdown.length > 0) {
    [types addObject:kENRMMarkdownPasteboardType];
  }
  [pasteboard declareTypes:types owner:nil];
  [pasteboard setString:plainText forType:NSPasteboardTypeString];
  if (markdown.length > 0) {
    [pasteboard setString:markdown forType:kENRMMarkdownPasteboardType];
  }
}

- (void)cut:(id)sender
{
  [self copy:sender];
  [self.markdownTextInput replaceSelectedTextWithParseResult:[ENRMParseResult resultWithPlainText:@""
                                                                                 formattingRanges:@[]
                                                                                     imageEntries:@[]]];
}

- (void)paste:(id)sender
{
  NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];

  NSString *markdown = [pasteboard stringForType:kENRMMarkdownPasteboardType];
  if (markdown.length > 0 && self.markdownTextInput != nil) {
    [self.markdownTextInput pasteMarkdown:markdown];
    return;
  }

  NSString *plainText = [pasteboard stringForType:NSPasteboardTypeString];
  if (plainText.length > 0) {
    [self insertText:plainText replacementRange:self.selectedRange];
  }
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
  if (menuItem.action == @selector(paste:)) {
    NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
    return ([pasteboard stringForType:NSPasteboardTypeString] != nil ||
            [pasteboard stringForType:kENRMMarkdownPasteboardType] != nil);
  }
  return [super validateMenuItem:menuItem];
}

- (BOOL)acceptsFirstResponder
{
  return self.isEditable;
}

- (void)mouseDown:(NSEvent *)event
{
  if (self.window != nil) {
    [self.window makeFirstResponder:self];
  }
  [super mouseDown:event];
}

- (NSMenu *)menuForEvent:(NSEvent *)event
{
  NSMenu *menu = [super menuForEvent:event];
  if (self.markdownTextInput != nil) {
    return [self.markdownTextInput enrichedMenuForEvent:event defaultMenu:menu textView:self];
  }
  return menu;
}

- (void)layout
{
  [super layout];
  if (self.markdownTextInput != nil) {
    [self.markdownTextInput scheduleRelayoutIfNeeded];
  }
}

@end

#endif
