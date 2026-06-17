#pragma once

#import "ENRMInputFormatter.h"
#import "ENRMUIKit.h"
#import "FontUtils.h"
#import <React/RCTConversions.h>

#if !TARGET_OS_OSX
static inline UITextAutocapitalizationType ENRMAutocapitalizationTypeFromString(NSString *value)
{
  if ([value isEqualToString:@"none"])
    return UITextAutocapitalizationTypeNone;
  if ([value isEqualToString:@"words"])
    return UITextAutocapitalizationTypeWords;
  if ([value isEqualToString:@"characters"])
    return UITextAutocapitalizationTypeAllCharacters;
  return UITextAutocapitalizationTypeSentences;
}
#endif

template <typename InputProps>
BOOL applyInputStyleProps(ENRMInputFormatterStyle *style, const InputProps &newProps, const InputProps &oldProps)
{
  BOOL changed = NO;

  if (newProps.fontSize != oldProps.fontSize) {
    CGFloat fontSize = newProps.fontSize > 0 ? newProps.fontSize : 16.0;
    style.baseFont = [style.baseFont fontWithSize:fontSize];
    changed = YES;
  }

  if (newProps.fontWeight != oldProps.fontWeight) {
    CGFloat fontSize = style.baseFont.pointSize;
    if (!newProps.fontWeight.empty()) {
      NSString *weightString = [NSString stringWithUTF8String:newProps.fontWeight.c_str()];
      UIFontWeight weight = ENRMFontWeightFromString(weightString);
      style.baseFont = [UIFont systemFontOfSize:fontSize weight:weight];
    } else {
      style.baseFont = [UIFont systemFontOfSize:fontSize];
    }
    changed = YES;
  }

  if (newProps.fontFamily != oldProps.fontFamily) {
    if (!newProps.fontFamily.empty()) {
      NSString *familyName = [NSString stringWithUTF8String:newProps.fontFamily.c_str()];
      UIFont *customFont = [UIFont fontWithName:familyName size:style.baseFont.pointSize];
      if (customFont) {
        style.baseFont = customFont;
      }
    } else {
      style.baseFont = [UIFont systemFontOfSize:style.baseFont.pointSize];
    }
    changed = YES;
  }

  if (newProps.color != oldProps.color) {
    if (isColorMeaningful(newProps.color)) {
      style.baseTextColor = RCTUIColorFromSharedColor(newProps.color);
    } else {
      style.baseTextColor = [RCTUIColor labelColor];
    }
    changed = YES;
  }

  if (newProps.markdownStyle.strong.color != oldProps.markdownStyle.strong.color) {
    if (isColorMeaningful(newProps.markdownStyle.strong.color)) {
      style.boldColor = RCTUIColorFromSharedColor(newProps.markdownStyle.strong.color);
    } else {
      style.boldColor = nil;
    }
    changed = YES;
  }

  if (newProps.markdownStyle.em.color != oldProps.markdownStyle.em.color) {
    if (isColorMeaningful(newProps.markdownStyle.em.color)) {
      style.italicColor = RCTUIColorFromSharedColor(newProps.markdownStyle.em.color);
    } else {
      style.italicColor = nil;
    }
    changed = YES;
  }

  if (newProps.markdownStyle.link.color != oldProps.markdownStyle.link.color) {
    style.linkColor = RCTUIColorFromSharedColor(newProps.markdownStyle.link.color);
    changed = YES;
  }

  if (newProps.markdownStyle.link.underline != oldProps.markdownStyle.link.underline) {
    style.linkUnderline = newProps.markdownStyle.link.underline;
    changed = YES;
  }

  if (newProps.markdownStyle.link.backgroundColor != oldProps.markdownStyle.link.backgroundColor) {
    RCTUIColor *backgroundColor = RCTUIColorFromSharedColor(newProps.markdownStyle.link.backgroundColor);
    style.linkBackgroundColor = CGColorGetAlpha(backgroundColor.CGColor) > 0 ? backgroundColor : nil;
    changed = YES;
  }

  {
    BOOL linkVariantsChanged = newProps.markdownStyle.linkVariants.size() != oldProps.markdownStyle.linkVariants.size();
    if (!linkVariantsChanged) {
      for (size_t i = 0; i < newProps.markdownStyle.linkVariants.size(); i++) {
        const auto &newVariant = newProps.markdownStyle.linkVariants[i];
        const auto &oldVariant = oldProps.markdownStyle.linkVariants[i];
        if (newVariant.pattern != oldVariant.pattern || newVariant.color != oldVariant.color ||
            newVariant.underline != oldVariant.underline || newVariant.backgroundColor != oldVariant.backgroundColor) {
          linkVariantsChanged = YES;
          break;
        }
      }
    }

    if (linkVariantsChanged) {
      NSMutableArray<ENRMInputLinkVariantStyle *> *variants = [NSMutableArray array];
      for (const auto &entry : newProps.markdownStyle.linkVariants) {
        ENRMInputLinkVariantStyle *variant = [[ENRMInputLinkVariantStyle alloc] init];
        variant.pattern = [[NSString alloc] initWithUTF8String:entry.pattern.c_str()];
        variant.color = RCTUIColorFromSharedColor(entry.color);
        variant.underline = entry.underline;
        RCTUIColor *backgroundColor = RCTUIColorFromSharedColor(entry.backgroundColor);
        variant.backgroundColor = CGColorGetAlpha(backgroundColor.CGColor) > 0 ? backgroundColor : nil;
        variant.regex = [NSRegularExpression regularExpressionWithPattern:variant.pattern options:0 error:nil];
        if (variant.regex != nil) {
          [variants addObject:variant];
        }
      }
      style.linkVariants = variants;
      changed = YES;
    }
  }

  if (newProps.markdownStyle.spoiler.color != oldProps.markdownStyle.spoiler.color) {
    style.spoilerColor = RCTUIColorFromSharedColor(newProps.markdownStyle.spoiler.color);
    changed = YES;
  }

  if (newProps.markdownStyle.spoiler.backgroundColor != oldProps.markdownStyle.spoiler.backgroundColor) {
    style.spoilerBackgroundColor = RCTUIColorFromSharedColor(newProps.markdownStyle.spoiler.backgroundColor);
    changed = YES;
  }

  return changed;
}
