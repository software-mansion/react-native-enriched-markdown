#import "ENRMInputRemend.h"

typedef struct {
  NSString *__unsafe_unretained open;
  NSString *__unsafe_unretained close;
  BOOL symmetric;
} ENRMDelimiterPair;

static const ENRMDelimiterPair kDelimiterPairs[] = {
    {@"**", @"**", YES}, {@"*", @"*", YES}, {@"_", @"_", YES}, {@"~~", @"~~", YES},
    {@"||", @"||", YES}, {@"`", @"`", YES}, {@"[", @"]", NO},
};
static const NSUInteger kDelimiterPairCount = sizeof(kDelimiterPairs) / sizeof(kDelimiterPairs[0]);

static NSString *closingForStackEntry(NSString *entry)
{
  for (NSUInteger i = 0; i < kDelimiterPairCount; i++) {
    if ([entry isEqualToString:kDelimiterPairs[i].open]) {
      return kDelimiterPairs[i].close;
    }
  }
  return entry;
}

NSString *ENRMInputRemendComplete(NSString *markdown)
{
  if (markdown.length == 0) {
    return markdown;
  }

  NSMutableArray<NSString *> *stack = [[NSMutableArray alloc] init];
  BOOL inLinkParen = NO;
  NSUInteger length = markdown.length;
  NSUInteger i = 0;

  while (i < length) {
    unichar c = [markdown characterAtIndex:i];

    if (c == '\\' && i + 1 < length) {
      i += 2;
      continue;
    }

    // Link URL parentheses are a special two-character transition from "]("
    if (c == ']' && !inLinkParen && i + 1 < length && [markdown characterAtIndex:i + 1] == '(') {
      NSUInteger bracketIndex = NSNotFound;
      for (NSUInteger idx = stack.count; idx > 0; idx--) {
        if ([stack[idx - 1] isEqualToString:@"["]) {
          bracketIndex = idx - 1;
          break;
        }
      }
      if (bracketIndex != NSNotFound) {
        [stack removeObjectsInRange:NSMakeRange(bracketIndex, stack.count - bracketIndex)];
      }
      inLinkParen = YES;
      i += 2;
      continue;
    }

    if (inLinkParen && c == ')') {
      inLinkParen = NO;
      i++;
      continue;
    }

    if (inLinkParen) {
      i++;
      continue;
    }

    BOOL matched = NO;
    for (NSUInteger p = 0; p < kDelimiterPairCount; p++) {
      ENRMDelimiterPair pair = kDelimiterPairs[p];
      NSUInteger openLen = pair.open.length;

      if (i + openLen > length) {
        continue;
      }

      NSString *substring = [markdown substringWithRange:NSMakeRange(i, openLen)];

      if (pair.symmetric) {
        if ([substring isEqualToString:pair.open]) {
          if (stack.count > 0 && [stack.lastObject isEqualToString:pair.open]) {
            [stack removeLastObject];
          } else {
            [stack addObject:pair.open];
          }
          i += openLen;
          matched = YES;
          break;
        }
      } else {
        if ([substring isEqualToString:pair.open]) {
          [stack addObject:pair.open];
          i += openLen;
          matched = YES;
          break;
        }
        NSUInteger closeLen = pair.close.length;
        if (i + closeLen <= length) {
          NSString *closeSub = [markdown substringWithRange:NSMakeRange(i, closeLen)];
          if ([closeSub isEqualToString:pair.close]) {
            if (stack.count > 0 && [stack.lastObject isEqualToString:pair.open]) {
              [stack removeLastObject];
            }
            i += closeLen;
            matched = YES;
            break;
          }
        }
      }
    }

    if (!matched) {
      i++;
    }
  }

  NSMutableString *closingSuffix = [NSMutableString string];

  if (inLinkParen) {
    [closingSuffix appendString:@")"];
  }

  for (NSString *entry in [stack reverseObjectEnumerator]) {
    [closingSuffix appendString:closingForStackEntry(entry)];
  }

  if (closingSuffix.length == 0) {
    return markdown;
  }

  return [markdown stringByAppendingString:closingSuffix];
}
