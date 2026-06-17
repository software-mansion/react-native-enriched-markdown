#import "ENRMLinkRegexConfig.h"

#import <React/RCTLog.h>

@implementation ENRMLinkRegexConfig

- (instancetype)initWithPattern:(NSString *)pattern
                caseInsensitive:(BOOL)caseInsensitive
                         dotAll:(BOOL)dotAll
                     isDisabled:(BOOL)isDisabled
                      isDefault:(BOOL)isDefault
{
  self = [super init];
  if (!self) {
    return nil;
  }

  _pattern = [pattern copy];
  _caseInsensitive = caseInsensitive;
  _dotAll = dotAll;
  _isDisabled = isDisabled;
  _isDefault = isDefault;
  _parsedRegex = nil;

  if (!_isDefault && !_isDisabled && _pattern.length > 0) {
    NSRegularExpressionOptions options = 0;
    if (_caseInsensitive) {
      options |= NSRegularExpressionCaseInsensitive;
    }
    if (_dotAll) {
      options |= NSRegularExpressionDotMatchesLineSeparators;
    }

    NSError *error = nil;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:_pattern
                                                                           options:options
                                                                             error:&error];
    if (error) {
      RCTLogWarn(
          @"[EnrichedMarkdownTextInput]: Couldn't parse the user-defined link regex '%@', "
           "falling back to default regex.",
          _pattern);
    } else {
      _parsedRegex = regex;
    }
  }

  return self;
}

- (BOOL)isEqualToConfig:(ENRMLinkRegexConfig *)other
{
  if (other == nil) {
    return NO;
  }
  return [_pattern isEqualToString:other.pattern] && _caseInsensitive == other.caseInsensitive &&
         _dotAll == other.dotAll && _isDefault == other.isDefault && _isDisabled == other.isDisabled;
}

@end
