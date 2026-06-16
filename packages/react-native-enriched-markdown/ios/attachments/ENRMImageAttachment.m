#import "ENRMImageAttachment.h"
#import "ENRMImageDownloader.h"
#import "ENRMUIKit.h"
#import "RuntimeKeys.h"
#import "StyleConfig.h"
#import <objc/runtime.h>

#define CACHE_KEY_PROCESSED(url, w, h, r) [NSString stringWithFormat:@"%@_w%.1f_h%.1f_r%.1f", url, w, h, r]

static inline NSUInteger ENRMImageByteCost(RCTUIImage *image)
{
  CGImageRef cgImage = image.CGImage;
  if (!cgImage)
    return 0;
  return CGImageGetBytesPerRow(cgImage) * CGImageGetHeight(cgImage);
}

static NSCache<NSString *, RCTUIImage *> *_originalImageCache;
static NSCache<NSString *, RCTUIImage *> *_processedImageCache;
static NSMapTable<NSString *, ENRMImageAttachment *> *_attachmentRegistry;

@interface ENRMImageAttachment ()

@property (nonatomic, copy) NSString *imageURL;
@property (nonatomic, assign) BOOL isInline;
@property (nonatomic, assign) CGFloat cachedHeight;
@property (nonatomic, assign) CGFloat cachedBorderRadius;
@property (nonatomic, weak) NSTextContainer *textContainer;
@property (nonatomic, weak) ENRMPlatformTextView *textView;
@property (nonatomic, strong) RCTUIImage *originalImage;
@property (nonatomic, strong) RCTUIImage *loadedImage;
@property (nonatomic, copy) NSString *lastProcessedKey;

@end

@implementation ENRMImageAttachment

+ (NSCache<NSString *, RCTUIImage *> *)originalImageCache
{
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    _originalImageCache = [[NSCache alloc] init];
    _originalImageCache.countLimit = 50;
    _originalImageCache.totalCostLimit = 1024 * 1024 * 20; // 20 MB
  });
  return _originalImageCache;
}

+ (NSCache<NSString *, RCTUIImage *> *)processedImageCache
{
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    _processedImageCache = [[NSCache alloc] init];
    _processedImageCache.countLimit = 100;
    _processedImageCache.totalCostLimit = 1024 * 1024 * 30; // 30 MB
  });
  return _processedImageCache;
}

+ (NSMapTable<NSString *, ENRMImageAttachment *> *)attachmentRegistry
{
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{ _attachmentRegistry = [NSMapTable strongToWeakObjectsMapTable]; });
  return _attachmentRegistry;
}

+ (instancetype)attachmentForURL:(NSString *)imageURL config:(StyleConfig *)config isInline:(BOOL)isInline
{
  NSString *key = [NSString stringWithFormat:@"%@_%d", imageURL, isInline];
  ENRMImageAttachment *existing = [[self attachmentRegistry] objectForKey:key];
  if (existing && existing.loadedImage) {
    return existing;
  }
  ENRMImageAttachment *attachment = [[self alloc] initWithImageURL:imageURL config:config isInline:isInline];
  [[self attachmentRegistry] setObject:attachment forKey:key];
  return attachment;
}

+ (void)clearAttachmentRegistry
{
  [[self attachmentRegistry] removeAllObjects];
}

- (instancetype)initWithImageURL:(NSString *)imageURL config:(StyleConfig *)config isInline:(BOOL)isInline
{
  self = [super init];
  if (self) {
    _imageURL = imageURL;
    _isInline = isInline;

    _cachedHeight = isInline ? [config inlineImageSize] : [config imageHeight];
    _cachedBorderRadius = [config imageBorderRadius];

    [self setupPlaceholder];
    [self startDownloadingImage];
  }
  return self;
}

- (CGRect)attachmentBoundsForTextContainer:(NSTextContainer *)textContainer
                      proposedLineFragment:(CGRect)lineFragment
                             glyphPosition:(CGPoint)position
                            characterIndex:(NSUInteger)characterIndex
{
  CGFloat height = self.cachedHeight;
  CGFloat width = self.isInline ? height : (lineFragment.size.width > 0 ? lineFragment.size.width : height);

  if (self.isInline) {
    UIFont *appliedFont = nil;
    NSLayoutManager *layoutManager = textContainer.layoutManager;
    NSTextStorage *textStorage = layoutManager.textStorage;

    if (textStorage && characterIndex < textStorage.length) {
      appliedFont = [textStorage attribute:NSFontAttributeName atIndex:characterIndex effectiveRange:NULL];
    }

    CGFloat verticalOffset;
    if (appliedFont) {
      verticalOffset = (appliedFont.capHeight - height) / 2.0;
    } else {
      verticalOffset = (lineFragment.size.height - height) / 2.0;
    }

    return CGRectMake(0, verticalOffset, width, height);
  }

  return CGRectMake(0, 0, width, height);
}

- (RCTUIImage *)imageForBounds:(CGRect)imageBounds
                 textContainer:(NSTextContainer *)textContainer
                characterIndex:(NSUInteger)characterIndex
{
  self.textContainer = textContainer;

  if (self.originalImage && imageBounds.size.width > 0) {
    self.bounds = imageBounds;
    [self processAndApplyImage:self.originalImage withTargetWidth:imageBounds.size.width];
  }

  return self.loadedImage ?: self.image;
}

- (void)handleLoadedImage:(RCTUIImage *)image
{
  if (!image)
    return;

  self.originalImage = image;
  CGFloat targetWidth = self.isInline ? self.cachedHeight : self.bounds.size.width;

  // Defer processing if we don't have valid bounds yet (common for non-inline block images)
  if (!self.isInline && targetWidth <= 0) {
    return;
  }

  [self processAndApplyImage:image withTargetWidth:targetWidth];
}

- (void)processAndApplyImage:(RCTUIImage *)image withTargetWidth:(CGFloat)targetWidth
{
  if (targetWidth <= 0)
    return;

  NSString *processedKey = CACHE_KEY_PROCESSED(self.imageURL, targetWidth, self.cachedHeight, self.cachedBorderRadius);

  if ([processedKey isEqualToString:self.lastProcessedKey])
    return;
  self.lastProcessedKey = processedKey;

  RCTUIImage *cachedProcessed = [[ENRMImageAttachment processedImageCache] objectForKey:processedKey];

  if (cachedProcessed) {
    self.loadedImage = cachedProcessed;
    if (self.isInline)
      self.image = cachedProcessed;
    [self refreshDisplay];
    return;
  }

  __weak typeof(self) weakSelf = self;
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
    __strong typeof(weakSelf) strongSelf = weakSelf;
    if (!strongSelf)
      return;

    RCTUIImage *processedImage = [strongSelf createScaledImage:image
                                                       toWidth:targetWidth
                                                        height:strongSelf.cachedHeight
                                                  borderRadius:strongSelf.cachedBorderRadius];

    if (processedImage) {
      [[ENRMImageAttachment processedImageCache] setObject:processedImage
                                                    forKey:processedKey
                                                      cost:ENRMImageByteCost(processedImage)];
    }

    dispatch_async(dispatch_get_main_queue(), ^{
      strongSelf.loadedImage = processedImage;
      if (strongSelf.isInline) {
        strongSelf.image = processedImage;
        strongSelf.bounds = CGRectMake(0, 0, strongSelf.cachedHeight, strongSelf.cachedHeight);
      } else {
        strongSelf.image = image; // Keep original for layout references
      }
      [strongSelf refreshDisplay];
    });
  });
}

- (RCTUIImage *)createScaledImage:(RCTUIImage *)image
                          toWidth:(CGFloat)targetWidth
                           height:(CGFloat)targetHeight
                     borderRadius:(CGFloat)radius
{
  CGFloat sourceWidth = image.size.width;
  CGFloat sourceHeight = image.size.height;
  if (sourceWidth <= 0 || sourceHeight <= 0)
    return nil;

  CGFloat drawingWidth, drawingHeight;

  if (!self.isInline) {
    CGFloat aspectRatioScale = targetWidth / sourceWidth;
    drawingWidth = targetWidth;
    drawingHeight = sourceHeight * aspectRatioScale;
  } else {
    drawingWidth = targetWidth;
    drawingHeight = targetHeight;
  }

  CGRect drawingRect =
      CGRectMake((targetWidth - drawingWidth) / 2.0, (targetHeight - drawingHeight) / 2.0, drawingWidth, drawingHeight);

  RCTUIGraphicsImageRenderer *renderer = ImageRendererForSize(CGSizeMake(targetWidth, targetHeight));

  return [renderer imageWithActions:^(RCTUIGraphicsImageRendererContext *context) {
    if (radius > 0) {
      CGRect clippingRect = CGRectIntersection(CGRectMake(0, 0, targetWidth, targetHeight), drawingRect);
      UIBezierPath *path = UIBezierPathWithRoundedRect(clippingRect, radius);
      [path addClip];
    }
    [image drawInRect:drawingRect];
  }];
}

- (void)startDownloadingImage
{
  if (self.imageURL.length == 0)
    return;

  __weak typeof(self) weakSelf = self;
  [[ENRMImageDownloader shared] downloadURL:self.imageURL
                                 completion:^(RCTUIImage *image) { [weakSelf handleLoadedImage:image]; }];
}

- (void)refreshDisplay
{
  UITextView *textView = [self fetchAssociatedTextView];
  if (!textView)
    return;

  NSRange range = [self findAttachmentRangeInText:textView.textStorage];
  if (range.location != NSNotFound) {
    [textView.layoutManager invalidateDisplayForCharacterRange:range];
    if (!self.isInline) {
      [textView.layoutManager invalidateLayoutForCharacterRange:range actualCharacterRange:NULL];
    }
  }
}

- (ENRMPlatformTextView *)fetchAssociatedTextView
{
  if (self.textView)
    return self.textView;
  if (!self.textContainer)
    return nil;
  self.textView = objc_getAssociatedObject(self.textContainer, kTextViewKey);
  return self.textView;
}

- (void)setupPlaceholder
{
  CGFloat size = self.cachedHeight;
  self.bounds = CGRectMake(0, 0, size, size);
  RCTUIGraphicsImageRenderer *renderer = [[RCTUIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(1, 1)];
  self.image = [renderer imageWithActions:^(RCTUIGraphicsImageRendererContext *ctx){}];
}

- (NSRange)findAttachmentRangeInText:(NSAttributedString *)attributedString
{
  __block NSRange foundRange = NSMakeRange(NSNotFound, 0);
  [attributedString enumerateAttribute:NSAttachmentAttributeName
                               inRange:NSMakeRange(0, attributedString.length)
                               options:0
                            usingBlock:^(id value, NSRange range, BOOL *stop) {
                              if (value == self) {
                                foundRange = range;
                                *stop = YES;
                              }
                            }];
  return foundRange;
}

@end