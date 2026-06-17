#pragma once
#import "ENRMUIKit.h"

NS_ASSUME_NONNULL_BEGIN

static NSString *const CodeBlockAttributeName = @"CodeBlock";

/**
 * Checks if the last element in the attributed string is a code block.
 * Used to compensate for iOS text APIs not measuring/drawing trailing newlines with custom line heights.
 */
static inline BOOL isLastElementCodeBlock(NSAttributedString *text)
{
  if (text.length == 0)
    return NO;

  NSRange lastContent = [text.string rangeOfCharacterFromSet:[[NSCharacterSet newlineCharacterSet] invertedSet]
                                                     options:NSBackwardsSearch];
  if (lastContent.location == NSNotFound)
    return NO;

  NSNumber *isCodeBlock = [text attribute:CodeBlockAttributeName atIndex:lastContent.location effectiveRange:nil];
  if (!isCodeBlock.boolValue)
    return NO;

  NSRange codeBlockRange;
  [text attribute:CodeBlockAttributeName atIndex:lastContent.location effectiveRange:&codeBlockRange];
  return NSMaxRange(codeBlockRange) == text.length;
}

/**
 * Checks if the last element in the attributed string is an image attachment.
 * Used to compensate for iOS text attachment baseline spacing issues.
 */
static inline BOOL isLastElementImage(NSAttributedString *text)
{
  if (text.length == 0)
    return NO;

  NSRange lastContent = [text.string rangeOfCharacterFromSet:[[NSCharacterSet newlineCharacterSet] invertedSet]
                                                     options:NSBackwardsSearch];
  if (lastContent.location == NSNotFound)
    return NO;

  unichar lastChar = [text.string characterAtIndex:lastContent.location];
  if (lastChar != 0xFFFC)
    return NO;

  id attachment = [text attribute:NSAttachmentAttributeName atIndex:lastContent.location effectiveRange:nil];
  return attachment != nil;
}

NS_ASSUME_NONNULL_END
