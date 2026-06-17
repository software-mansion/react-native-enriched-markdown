#import "ENRMAutoLinkDetector.h"

#import "ENRMFormattingRange.h"
#import "InputStylePropsUtils.h"

static NSAttributedStringKey const ENRMAutomaticLinkAttributeName = @"ENRMAutomaticLink";

@implementation ENRMAutoLinkDetector {
  __weak NSTextStorage *_textStorage;
  __weak ENRMFormattingStore *_formattingStore;
  __weak ENRMInputFormatterStyle *_style;
  ENRMLinkRegexConfig *_regexConfig;
}

- (instancetype)initWithTextStorage:(NSTextStorage *)textStorage
                    formattingStore:(ENRMFormattingStore *)store
                              style:(ENRMInputFormatterStyle *)style
{
  self = [super init];
  if (self) {
    _textStorage = textStorage;
    _formattingStore = store;
    _style = style;
  }
  return self;
}

- (void)setRegexConfig:(ENRMLinkRegexConfig *)config
{
  _regexConfig = config;
}

#pragma mark - ENRMTextDetector

- (void)processWord:(ENRMWordResult *)wordResult
{
  NSString *detectedUrl = [self detectNewLinkAtRange:wordResult.range inText:wordResult.word];
  if (detectedUrl != nil && _onLinkDetected != nil) {
    _onLinkDetected(wordResult.word, detectedUrl, wordResult.range);
  }
}

- (void)refreshStyling
{
  NSTextStorage *textStorage = _textStorage;
  if (textStorage == nil || textStorage.length == 0) {
    return;
  }

  [textStorage beginEditing];
  [textStorage enumerateAttribute:ENRMAutomaticLinkAttributeName
                          inRange:NSMakeRange(0, textStorage.length)
                          options:0
                       usingBlock:^(id value, NSRange range, BOOL *stop) {
                         if (value != nil) {
                           [self applyVisualStylingToRange:range];
                         }
                       }];
  [textStorage endEditing];
}

- (NSArray<ENRMFormattingRange *> *)transientFormattingRanges
{
  NSTextStorage *textStorage = _textStorage;
  if (textStorage == nil || textStorage.length == 0) {
    return @[];
  }

  NSMutableArray<ENRMFormattingRange *> *ranges = [NSMutableArray array];
  [textStorage enumerateAttribute:ENRMAutomaticLinkAttributeName
                          inRange:NSMakeRange(0, textStorage.length)
                          options:0
                       usingBlock:^(id value, NSRange range, BOOL *stop) {
                         if (value != nil && [value isKindOfClass:[NSString class]]) {
                           ENRMFormattingRange *fmtRange = [ENRMFormattingRange rangeWithType:ENRMInputStyleTypeLink
                                                                                        range:range
                                                                                          url:value];
                           [ranges addObject:fmtRange];
                         }
                       }];
  return ranges;
}

- (void)clearAutoLinkInRange:(NSRange)range
{
  NSTextStorage *textStorage = _textStorage;
  if (textStorage == nil || NSMaxRange(range) > textStorage.length) {
    return;
  }
  [textStorage removeAttribute:ENRMAutomaticLinkAttributeName range:range];
}

#pragma mark - Link matching

- (nullable NSString *)detectNewLinkAtRange:(NSRange)wordRange inText:(NSString *)word
{
  if (_regexConfig != nil && _regexConfig.isDisabled) {
    return nil;
  }

  NSTextStorage *textStorage = _textStorage;
  if (textStorage == nil) {
    return nil;
  }

  if (NSMaxRange(wordRange) > textStorage.length) {
    return nil;
  }

  ENRMFormattingStore *store = _formattingStore;
  if (store != nil) {
    ENRMFormattingRange *manualLink = [store rangeOfType:ENRMInputStyleTypeLink containingPosition:wordRange.location];
    if (manualLink != nil) {
      return nil;
    }
  }

  NSString *matchedUrl = [self tryMatchWord:word];

  if (matchedUrl != nil) {
    NSRange effectiveRange;
    id existing = [textStorage attribute:ENRMAutomaticLinkAttributeName
                                 atIndex:wordRange.location
                          effectiveRange:&effectiveRange];
    BOOL alreadyApplied = [matchedUrl isEqual:existing] && NSEqualRanges(effectiveRange, wordRange);

    if (!alreadyApplied) {
      [textStorage beginEditing];
      [textStorage addAttribute:ENRMAutomaticLinkAttributeName value:matchedUrl range:wordRange];
      [self applyVisualStylingToRange:wordRange];
      [textStorage endEditing];
    }
  } else {
    id existing = [textStorage attribute:ENRMAutomaticLinkAttributeName atIndex:wordRange.location effectiveRange:nil];
    if (existing != nil) {
      [textStorage beginEditing];
      [textStorage removeAttribute:ENRMAutomaticLinkAttributeName range:wordRange];
      [textStorage endEditing];
    }
  }

  return matchedUrl;
}

- (nullable NSString *)tryMatchWord:(NSString *)word
{
  if (word.length == 0) {
    return nil;
  }

  NSRange matchRange = NSMakeRange(0, word.length);

  if (_regexConfig != nil && !_regexConfig.isDefault && _regexConfig.parsedRegex != nil) {
    if ([_regexConfig.parsedRegex numberOfMatchesInString:word options:0 range:matchRange]) {
      return [ENRMAutoLinkDetector normalizeUrl:word];
    }
    return nil;
  }

  if ([[ENRMAutoLinkDetector defaultRegex] numberOfMatchesInString:word options:0 range:matchRange]) {
    return [ENRMAutoLinkDetector normalizeUrl:word];
  }

  return nil;
}

+ (NSString *)normalizeUrl:(NSString *)url
{
  if ([url hasPrefix:@"http://"] || [url hasPrefix:@"https://"]) {
    return url;
  }
  return [@"https://" stringByAppendingString:url];
}

#pragma mark - Visual styling

- (void)applyVisualStylingToRange:(NSRange)range
{
  NSTextStorage *textStorage = _textStorage;
  ENRMInputFormatterStyle *style = _style;
  if (textStorage == nil || style == nil) {
    return;
  }

  [textStorage addAttribute:NSForegroundColorAttributeName value:style.linkColor range:range];
  if (style.linkUnderline) {
    [textStorage addAttribute:NSUnderlineStyleAttributeName value:@(NSUnderlineStyleSingle) range:range];
  }
}

#pragma mark - Default regex

+ (NSRegularExpression *)defaultRegex
{
  static NSRegularExpression *regex;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    NSError *error = nil;
    regex = [NSRegularExpression
        regularExpressionWithPattern:
            @"(?:https?://[-a-zA-Z0-9@:%._\\+~#=]{1,256}\\.[a-z]{2,6}\\b[-a-zA-Z0-9@:%_\\+.~#?&//=]*"
            @"|www\\.[-a-zA-Z0-9@:%._\\+~#=]{1,256}\\.[a-z]{2,6}\\b[-a-zA-Z0-9@:%_\\+.~#?&//=]*"
            @"|[-a-zA-Z0-9@:%._\\+~#=]{1,256}\\.[a-z]{2,6}\\b[-a-zA-Z0-9@:%_\\+.~#?&//=]*)"
                             options:NSRegularExpressionCaseInsensitive
                               error:&error];
    NSCAssert(regex != nil, @"ENRMAutoLinkDetector: failed to compile default regex: %@", error);
  });
  return regex;
}

@end
