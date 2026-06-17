#import "ENRMMarkdownSerializer.h"

static NSString *openingDelimiterForType(ENRMInputStyleType type)
{
  switch (type) {
    case ENRMInputStyleTypeStrong:
      return @"**";
    case ENRMInputStyleTypeEmphasis:
      return @"*";
    case ENRMInputStyleTypeUnderline:
      return @"_";
    case ENRMInputStyleTypeStrikethrough:
      return @"~~";
    case ENRMInputStyleTypeLink:
      return @"[";
    case ENRMInputStyleTypeSpoiler:
      return @"||";
    default:
      return @"";
  }
}

static NSString *closingDelimiterForType(ENRMInputStyleType type, NSString *url)
{
  switch (type) {
    case ENRMInputStyleTypeStrong:
      return @"**";
    case ENRMInputStyleTypeEmphasis:
      return @"*";
    case ENRMInputStyleTypeUnderline:
      return @"_";
    case ENRMInputStyleTypeStrikethrough:
      return @"~~";
    case ENRMInputStyleTypeLink:
      return [NSString stringWithFormat:@"](%@)", url ?: @""];
    case ENRMInputStyleTypeSpoiler:
      return @"||";
    default:
      return @"";
  }
}

/// Lower value = outermost wrapper. Font styles wrap around structural styles (link).
static int nestingPriorityForType(ENRMInputStyleType type)
{
  switch (type) {
    case ENRMInputStyleTypeEmphasis:
      return 0;
    case ENRMInputStyleTypeStrong:
      return 1;
    case ENRMInputStyleTypeUnderline:
      return 2;
    case ENRMInputStyleTypeStrikethrough:
      return 3;
    case ENRMInputStyleTypeSpoiler:
      return 4;
    case ENRMInputStyleTypeLink:
      return 5;
    default:
      return 99;
  }
}

typedef struct {
  NSUInteger position;
  BOOL isOpening;
  ENRMInputStyleType type;
  NSString *__unsafe_unretained url;
} BoundaryEvent;

static int compareBoundaryEvents(const void *first, const void *second)
{
  const BoundaryEvent *eventA = (const BoundaryEvent *)first;
  const BoundaryEvent *eventB = (const BoundaryEvent *)second;

  if (eventA->position != eventB->position) {
    return eventA->position < eventB->position ? -1 : 1;
  }
  // Closing events before opening events at the same position
  if (eventA->isOpening != eventB->isOpening) {
    return eventA->isOpening ? 1 : -1;
  }
  // Among openings: outer first (lower priority emitted first)
  // Among closings: inner first (higher priority emitted first) — LIFO order
  int priorityA = nestingPriorityForType(eventA->type);
  int priorityB = nestingPriorityForType(eventB->type);
  if (eventA->isOpening) {
    return priorityA - priorityB;
  } else {
    return priorityB - priorityA;
  }
}

static NSCharacterSet *whitespaceSet(void)
{
  static NSCharacterSet *set;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{ set = [NSCharacterSet whitespaceCharacterSet]; });
  return set;
}

/// Split formatting ranges at paragraph breaks (\n\n) so each segment gets
/// its own delimiters — CommonMark delimiters can't span paragraphs.
/// NOTE: This only handles inline styles (bold, italic, etc.). Block-level
/// elements (lists, blockquotes, headings) are prefix-based and will need
/// a separate serialization path.
static NSArray<ENRMFormattingRange *> *splitRangesAtParagraphBreaks(NSArray<ENRMFormattingRange *> *ranges,
                                                                    NSString *text)
{
  NSMutableArray<ENRMFormattingRange *> *result = [NSMutableArray arrayWithCapacity:ranges.count];

  NSUInteger textLength = text.length;

  for (ENRMFormattingRange *formattingRange in ranges) {
    NSUInteger rangeStart = MIN(formattingRange.range.location, textLength);
    NSUInteger rangeEnd = MIN(NSMaxRange(formattingRange.range), textLength);

    NSUInteger segStart = rangeStart;
    while (segStart < rangeEnd) {
      NSUInteger segEnd = segStart;
      while (segEnd < rangeEnd) {
        if (segEnd + 1 < rangeEnd && [text characterAtIndex:segEnd] == '\n' &&
            [text characterAtIndex:segEnd + 1] == '\n') {
          break;
        }
        segEnd++;
      }

      if (segEnd > segStart) {
        [result addObject:[ENRMFormattingRange rangeWithType:formattingRange.type
                                                       range:NSMakeRange(segStart, segEnd - segStart)
                                                         url:formattingRange.url]];
      }

      segStart = (segEnd < rangeEnd && segEnd + 1 < rangeEnd && [text characterAtIndex:segEnd] == '\n' &&
                  [text characterAtIndex:segEnd + 1] == '\n')
                     ? segEnd + 2
                     : segEnd;
    }
  }

  return result;
}

@implementation ENRMMarkdownSerializer

+ (NSString *)serializePlainText:(NSString *)text ranges:(NSArray<ENRMFormattingRange *> *)ranges
{
  if (ranges.count == 0) {
    return text;
  }

  NSArray<ENRMFormattingRange *> *splitRanges = splitRangesAtParagraphBreaks(ranges, text);

  NSUInteger textLength = text.length;
  NSUInteger eventCount = splitRanges.count * 2;

  BoundaryEvent *events = (BoundaryEvent *)malloc(sizeof(BoundaryEvent) * eventCount);
  if (!events)
    return text;

  NSCharacterSet *ws = whitespaceSet();
  NSUInteger eventIndex = 0;
  for (ENRMFormattingRange *formattingRange in splitRanges) {
    NSUInteger start = MIN(formattingRange.range.location, textLength);
    NSUInteger end = MIN(NSMaxRange(formattingRange.range), textLength);

    while (start < end && [ws characterIsMember:[text characterAtIndex:start]]) {
      start++;
    }
    while (end > start && [ws characterIsMember:[text characterAtIndex:end - 1]]) {
      end--;
    }

    if (start >= end) {
      continue;
    }

    events[eventIndex++] = (BoundaryEvent){
        .position = start,
        .isOpening = YES,
        .type = formattingRange.type,
        .url = formattingRange.url,
    };
    events[eventIndex++] = (BoundaryEvent){
        .position = end,
        .isOpening = NO,
        .type = formattingRange.type,
        .url = formattingRange.url,
    };
  }

  qsort(events, eventIndex, sizeof(BoundaryEvent), compareBoundaryEvents);

  NSMutableString *markdown = [NSMutableString stringWithCapacity:textLength + eventCount * 4];
  NSUInteger lastPosition = 0;

  for (NSUInteger currentEvent = 0; currentEvent < eventIndex; currentEvent++) {
    BoundaryEvent event = events[currentEvent];
    NSUInteger position = MIN(event.position, textLength);

    if (position > lastPosition) {
      [markdown appendString:[text substringWithRange:NSMakeRange(lastPosition, position - lastPosition)]];
      lastPosition = position;
    }

    if (event.isOpening) {
      [markdown appendString:openingDelimiterForType(event.type)];
    } else {
      [markdown appendString:closingDelimiterForType(event.type, event.url)];
    }
  }

  if (lastPosition < textLength) {
    [markdown appendString:[text substringFromIndex:lastPosition]];
  }

  free(events);
  return markdown;
}

@end
