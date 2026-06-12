#import "DataDetectorUtils.h"
#import <React/RCTFont.h>

NSString *const ENRMDataDetectorTypeAttributeName = @"ENRMDataDetectorType";
NSString *const ENRMDataDetectorDataAttributeName = @"ENRMDataDetectorData";

#ifdef __cplusplus
ENRMDataDetectorType ENRMParseDataDetectorTypes(const std::vector<std::string> &types)
{
  ENRMDataDetectorType result = ENRMDataDetectorTypeNone;
  for (const auto &type : types) {
    if (type == "phoneNumber") {
      result |= ENRMDataDetectorTypePhoneNumber;
    } else if (type == "link") {
      result |= ENRMDataDetectorTypeLink;
    } else if (type == "email") {
      result |= ENRMDataDetectorTypeEmail;
    } else if (type == "address") {
      result |= ENRMDataDetectorTypeAddress;
    } else if (type == "date") {
      result |= ENRMDataDetectorTypeDate;
    }
  }
  return result;
}
#endif

static NSTextCheckingTypes checkingTypesForDetectorTypes(ENRMDataDetectorType types)
{
  NSTextCheckingTypes result = 0;
  if (types & ENRMDataDetectorTypePhoneNumber) {
    result |= NSTextCheckingTypePhoneNumber;
  }
  if (types & ENRMDataDetectorTypeLink) {
    result |= NSTextCheckingTypeLink;
  }
  if (types & ENRMDataDetectorTypeEmail) {
    result |= NSTextCheckingTypeLink;
  }
  if (types & ENRMDataDetectorTypeAddress) {
    result |= NSTextCheckingTypeAddress;
  }
  if (types & ENRMDataDetectorTypeDate) {
    result |= NSTextCheckingTypeDate;
  }
  return result;
}

static NSString *detectorTypeStringForResult(NSTextCheckingResult *result, ENRMDataDetectorType requestedTypes)
{
  switch (result.resultType) {
    case NSTextCheckingTypePhoneNumber:
      return @"phoneNumber";
    case NSTextCheckingTypeLink: {
      NSString *scheme = result.URL.scheme.lowercaseString;
      if ([scheme isEqualToString:@"mailto"] && (requestedTypes & ENRMDataDetectorTypeEmail)) {
        return @"email";
      }
      return @"link";
    }
    case NSTextCheckingTypeAddress:
      return @"address";
    case NSTextCheckingTypeDate:
      return @"date";
    default:
      return @"link";
  }
}

static NSISO8601DateFormatter *sharedISO8601Formatter(void)
{
  static NSISO8601DateFormatter *formatter;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{ formatter = [[NSISO8601DateFormatter alloc] init]; });
  return formatter;
}

static NSString *dataJsonForResult(NSTextCheckingResult *result)
{
  NSMutableDictionary *dict = [NSMutableDictionary dictionary];
  switch (result.resultType) {
    case NSTextCheckingTypePhoneNumber:
      if (result.phoneNumber)
        dict[@"phoneNumber"] = result.phoneNumber;
      break;
    case NSTextCheckingTypeLink: {
      NSString *scheme = result.URL.scheme.lowercaseString;
      if ([scheme isEqualToString:@"mailto"]) {
        NSString *email = result.URL.resourceSpecifier;
        if (email)
          dict[@"email"] = email;
      } else {
        dict[@"url"] = result.URL.absoluteString;
      }
      break;
    }
    case NSTextCheckingTypeAddress: {
      NSDictionary *components = result.addressComponents;
      if (components[NSTextCheckingStreetKey])
        dict[@"street"] = components[NSTextCheckingStreetKey];
      if (components[NSTextCheckingCityKey])
        dict[@"city"] = components[NSTextCheckingCityKey];
      if (components[NSTextCheckingStateKey])
        dict[@"state"] = components[NSTextCheckingStateKey];
      if (components[NSTextCheckingZIPKey])
        dict[@"zip"] = components[NSTextCheckingZIPKey];
      if (components[NSTextCheckingCountryKey])
        dict[@"country"] = components[NSTextCheckingCountryKey];
      break;
    }
    case NSTextCheckingTypeDate: {
      if (result.date) {
        dict[@"date"] = [sharedISO8601Formatter() stringFromDate:result.date];
      }
      if (result.duration > 0) {
        dict[@"duration"] = [NSString stringWithFormat:@"%.0f", result.duration];
      }
      break;
    }
    default:
      break;
  }
  if (dict.count == 0)
    return @"{}";
  NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dict options:0 error:nil];
  return jsonData ? [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding] : @"{}";
}

static NSString *urlForResult(NSTextCheckingResult *result)
{
  switch (result.resultType) {
    case NSTextCheckingTypePhoneNumber:
      return [NSString stringWithFormat:@"tel:%@", result.phoneNumber];
    case NSTextCheckingTypeLink:
      return result.URL.absoluteString;
    case NSTextCheckingTypeAddress: {
      NSDictionary *components = result.addressComponents;
      NSMutableString *address = [NSMutableString string];
      NSString *street = components[NSTextCheckingStreetKey];
      NSString *city = components[NSTextCheckingCityKey];
      NSString *state = components[NSTextCheckingStateKey];
      NSString *zip = components[NSTextCheckingZIPKey];
      NSString *country = components[NSTextCheckingCountryKey];
      if (street)
        [address appendString:street];
      if (city)
        [address appendFormat:@"%@%@", address.length > 0 ? @", " : @"", city];
      if (state)
        [address appendFormat:@"%@%@", address.length > 0 ? @", " : @"", state];
      if (zip)
        [address appendFormat:@" %@", zip];
      if (country)
        [address appendFormat:@"%@%@", address.length > 0 ? @", " : @"", country];
      return address.length > 0 ? address : @"";
    }
    case NSTextCheckingTypeDate: {
      if (result.date) {
        return [sharedISO8601Formatter() stringFromDate:result.date];
      }
      return @"";
    }
    default:
      return @"";
  }
}

static NSDataDetector *_Nullable cachedDetectorForTypes(ENRMDataDetectorType types)
{
  static NSMutableDictionary<NSNumber *, NSDataDetector *> *cache;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{ cache = [NSMutableDictionary dictionary]; });

  NSNumber *key = @(types);
  NSDataDetector *detector = cache[key];
  if (!detector) {
    NSTextCheckingTypes checkingTypes = checkingTypesForDetectorTypes(types);
    NSError *error = nil;
    detector = [NSDataDetector dataDetectorWithTypes:checkingTypes error:&error];
    if (detector) {
      cache[key] = detector;
    }
  }
  return detector;
}

BOOL ENRMApplyDataDetection(NSMutableAttributedString *attributedText, ENRMDataDetectorType types,
                            RCTUIColor *_Nullable linkColor, BOOL linkUnderline, NSString *_Nullable linkFontFamily)
{
  if (types == ENRMDataDetectorTypeNone || attributedText.length == 0) {
    return NO;
  }

  NSDataDetector *detector = cachedDetectorForTypes(types);
  if (!detector) {
    return NO;
  }

  NSString *plainText = attributedText.string;
  NSArray<NSTextCheckingResult *> *matches = [detector matchesInString:plainText
                                                               options:0
                                                                 range:NSMakeRange(0, plainText.length)];

  if (matches.count == 0) {
    return NO;
  }

  NSNumber *underlineStyle = @(linkUnderline ? NSUnderlineStyleSingle : NSUnderlineStyleNone);
  BOOL didApply = NO;

  for (NSTextCheckingResult *match in matches) {
    NSRange range = match.range;

    // Skip if this range already has a linkURL (from explicit markdown links)
    __block BOOL hasExistingLink = NO;
    [attributedText enumerateAttribute:@"linkURL"
                               inRange:range
                               options:0
                            usingBlock:^(id _Nullable value, NSRange attrRange, BOOL *stop) {
                              if (value != nil) {
                                hasExistingLink = YES;
                                *stop = YES;
                              }
                            }];

    if (hasExistingLink) {
      continue;
    }

    // For email type filter: only apply if the detected URL is mailto
    if (match.resultType == NSTextCheckingTypeLink) {
      NSString *scheme = match.URL.scheme.lowercaseString;
      BOOL isEmail = [scheme isEqualToString:@"mailto"];
      if (isEmail && !(types & ENRMDataDetectorTypeEmail)) {
        continue;
      }
      if (!isEmail && !(types & ENRMDataDetectorTypeLink)) {
        continue;
      }
    }

    NSString *typeString = detectorTypeStringForResult(match, types);
    NSString *url = urlForResult(match);
    NSString *dataJson = dataJsonForResult(match);

    [attributedText addAttribute:@"linkURL" value:url range:range];
    [attributedText addAttribute:ENRMDataDetectorTypeAttributeName value:typeString range:range];
    [attributedText addAttribute:ENRMDataDetectorDataAttributeName value:dataJson range:range];
    [attributedText addAttribute:NSLinkAttributeName value:url range:range];

    if (linkColor) {
      [attributedText addAttribute:NSForegroundColorAttributeName value:linkColor range:range];
      [attributedText addAttribute:NSUnderlineColorAttributeName value:linkColor range:range];
    }
    [attributedText addAttribute:NSUnderlineStyleAttributeName value:underlineStyle range:range];

    if (linkFontFamily.length > 0) {
      [attributedText enumerateAttribute:NSFontAttributeName
                                 inRange:range
                                 options:0
                              usingBlock:^(UIFont *currentFont, NSRange subrange, BOOL *stop) {
                                if (!currentFont)
                                  return;
                                UIFont *linkFont = [RCTFont updateFont:currentFont
                                                            withFamily:linkFontFamily
                                                                  size:nil
                                                                weight:nil
                                                                 style:nil
                                                               variant:nil
                                                       scaleMultiplier:1.0];
                                if (linkFont && ![currentFont isEqual:linkFont]) {
                                  [attributedText addAttribute:NSFontAttributeName value:linkFont range:subrange];
                                }
                              }];
    }

    didApply = YES;
  }

  return didApply;
}

NSString *_Nullable ENRMDataDetectorTypeAtIndex(NSAttributedString *attributedText, NSUInteger index)
{
  if (index >= attributedText.length) {
    return nil;
  }
  return [attributedText attribute:ENRMDataDetectorTypeAttributeName atIndex:index effectiveRange:NULL];
}

NSString *_Nullable ENRMDataDetectorDataAtIndex(NSAttributedString *attributedText, NSUInteger index)
{
  if (index >= attributedText.length) {
    return nil;
  }
  return [attributedText attribute:ENRMDataDetectorDataAttributeName atIndex:index effectiveRange:NULL];
}

@implementation ENRMDataDetectorTapInfo

- (instancetype)initWithType:(NSString *)type text:(NSString *)text dataJson:(NSString *)dataJson
{
  if (self = [super init]) {
    _type = type;
    _text = text;
    _dataJson = dataJson;
  }
  return self;
}

@end

ENRMDataDetectorTapInfo *_Nullable ENRMDataDetectorTapInfoAtIndex(NSAttributedString *attributedText,
                                                                  NSUInteger charIndex)
{
  if (charIndex == NSNotFound || charIndex >= attributedText.length) {
    return nil;
  }
  NSString *detectorType = [attributedText attribute:ENRMDataDetectorTypeAttributeName
                                             atIndex:charIndex
                                      effectiveRange:NULL];
  if (!detectorType) {
    return nil;
  }
  NSRange effectiveRange;
  [attributedText attribute:ENRMDataDetectorTypeAttributeName atIndex:charIndex effectiveRange:&effectiveRange];
  NSString *matchedText = [attributedText.string substringWithRange:effectiveRange];
  NSString *dataJson = ENRMDataDetectorDataAtIndex(attributedText, charIndex) ?: @"{}";
  return [[ENRMDataDetectorTapInfo alloc] initWithType:detectorType text:matchedText dataJson:dataJson];
}
