#import "StreamingMarkdownFilter.h"

static BOOL ENRMLineIsBlank(NSString *line)
{
  return [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]].length == 0;
}

static BOOL ENRMLineIsBlockMathDelimiter(NSString *line)
{
  return [[line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] isEqualToString:@"$$"];
}

static BOOL ENRMLineLooksLikeTableRow(NSString *line)
{
  NSString *trimmed = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
  return [trimmed hasPrefix:@"|"];
}

static NSUInteger ENRMPipeCount(NSString *line)
{
  NSUInteger count = 0;
  for (NSUInteger i = 0; i < line.length; i++) {
    if ([line characterAtIndex:i] == '|') {
      count++;
    }
  }
  return count;
}

static BOOL ENRMLineLooksLikeTableSeparator(NSString *line)
{
  NSString *trimmed = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
  if (trimmed.length == 0) {
    return NO;
  }
  if ([trimmed characterAtIndex:0] != '|') {
    return NO;
  }
  BOOL hasTripleDash = NO;
  NSUInteger dashRun = 0;
  for (NSUInteger i = 0; i < trimmed.length; i++) {
    unichar ch = [trimmed characterAtIndex:i];
    if (ch == '-') {
      dashRun++;
      if (dashRun >= 3) {
        hasTripleDash = YES;
      }
    } else {
      dashRun = 0;
      if (ch != '|' && ch != ':' && ch != ' ') {
        return NO;
      }
    }
  }
  return hasTripleDash;
}

static NSUInteger *ENRMBuildLineOffsets(NSArray<NSString *> *lines, NSUInteger count)
{
  NSUInteger *offsets = (NSUInteger *)calloc(count, sizeof(NSUInteger));
  NSUInteger currentOffset = 0;
  for (NSUInteger i = 0; i < count; i++) {
    offsets[i] = currentOffset;
    currentOffset += lines[i].length + 1;
  }
  return offsets;
}

static NSString *ENRMRemovePendingStreamingMathBlock(NSString *markdown, NSArray<NSString *> *lines)
{
  NSInteger lastUnclosedDelimiterIndex = -1;

  for (NSUInteger i = 0; i < lines.count; i++) {
    if (ENRMLineIsBlockMathDelimiter(lines[i])) {
      lastUnclosedDelimiterIndex = lastUnclosedDelimiterIndex == -1 ? (NSInteger)i : -1;
    }
  }

  if (lastUnclosedDelimiterIndex == -1) {
    return markdown;
  }

  NSUInteger *offsets = ENRMBuildLineOffsets(lines, lines.count);
  NSString *result = [markdown substringToIndex:offsets[(NSUInteger)lastUnclosedDelimiterIndex]];
  free(offsets);
  return result;
}

static NSString *ENRMRemovePendingStreamingTableBlock(NSString *markdown, NSArray<NSString *> *lines,
                                                      ENRMTableStreamingMode tableMode)
{
  NSInteger lastNonBlankLineIndex = -1;

  for (NSInteger i = (NSInteger)lines.count - 1; i >= 0; i--) {
    if (!ENRMLineIsBlank(lines[(NSUInteger)i])) {
      lastNonBlankLineIndex = i;
      break;
    }
  }

  if (lastNonBlankLineIndex == -1) {
    return markdown;
  }

  if ((NSUInteger)lastNonBlankLineIndex + 1 < lines.count - 1) {
    return markdown;
  }

  NSInteger blockStartIndex = lastNonBlankLineIndex;
  while (blockStartIndex > 0 && !ENRMLineIsBlank(lines[(NSUInteger)blockStartIndex - 1])) {
    blockStartIndex--;
  }

  BOOL blockLooksLikeTable = NO;
  for (NSInteger i = blockStartIndex; i <= lastNonBlankLineIndex; i++) {
    NSString *line = lines[(NSUInteger)i];
    if (!ENRMLineLooksLikeTableRow(line)) {
      return markdown;
    }
    blockLooksLikeTable = YES;
  }

  if (!blockLooksLikeTable) {
    return markdown;
  }

  NSUInteger *offsets = ENRMBuildLineOffsets(lines, lines.count);

  if (tableMode == ENRMTableStreamingModeProgressive) {
    NSInteger tableLineCount = lastNonBlankLineIndex - blockStartIndex + 1;

    if (tableLineCount < 2 || !ENRMLineLooksLikeTableSeparator(lines[(NSUInteger)blockStartIndex + 1])) {
      NSString *result = [markdown substringToIndex:offsets[(NSUInteger)blockStartIndex]];
      free(offsets);
      return result;
    }

    if (tableLineCount > 2) {
      NSString *lastRow = lines[(NSUInteger)lastNonBlankLineIndex];
      NSString *lastRowTrimmed = [lastRow stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
      NSString *headerRow = lines[(NSUInteger)blockStartIndex];
      if (![lastRowTrimmed hasSuffix:@"|"] || ENRMPipeCount(lastRow) < ENRMPipeCount(headerRow)) {
        NSString *result = [markdown substringToIndex:offsets[(NSUInteger)lastNonBlankLineIndex]];
        free(offsets);
        return result;
      }
    }

    free(offsets);
    return markdown;
  }

  NSString *result = [markdown substringToIndex:offsets[(NSUInteger)blockStartIndex]];
  free(offsets);
  return result;
}

NSString *ENRMRenderableMarkdownForStreaming(NSString *markdown, ENRMTableStreamingMode tableMode)
{
  NSArray<NSString *> *lines = [markdown componentsSeparatedByString:@"\n"];
  NSString *afterMath = ENRMRemovePendingStreamingMathBlock(markdown, lines);
  NSArray<NSString *> *linesForTable =
      (afterMath.length == markdown.length) ? lines : [afterMath componentsSeparatedByString:@"\n"];
  return ENRMRemovePendingStreamingTableBlock(afterMath, linesForTable, tableMode);
}
