import { Platform, processColor, type ColorValue } from 'react-native';
import type { MarkdownStyle } from './types/MarkdownStyle';

export const normalizeColor = (
  color: string | undefined
): ColorValue | undefined => {
  if (!color) return undefined;
  if (Platform.OS === 'web') return color;
  return processColor(color) ?? undefined;
};

export function mergeSubStyle<T extends Record<string, unknown>>(
  defaultStyle: T,
  userStyle?: Partial<T>
): T {
  if (!userStyle) return defaultStyle;
  const result: Record<string, unknown> = { ...defaultStyle, ...userStyle };
  for (const key in result) {
    const defaultValue = defaultStyle[key];
    const userValue = userStyle[key];
    if (
      typeof defaultValue === 'object' &&
      defaultValue !== null &&
      !Array.isArray(defaultValue) &&
      typeof userValue === 'object' &&
      userValue !== null &&
      !Array.isArray(userValue)
    ) {
      result[key] = {
        ...(defaultValue as Record<string, unknown>),
        ...(userValue as Record<string, unknown>),
      };
    }
    if (
      key.toLowerCase().includes('color') &&
      typeof result[key] === 'string'
    ) {
      result[key] = normalizeColor(result[key] as string);
    }
  }
  return result as T;
}

function isSubStyleEqual(
  a: Record<string, unknown>,
  b: Record<string, unknown>
): boolean {
  const keys = Object.keys(a);
  if (keys.length !== Object.keys(b).length) return false;
  for (const key of keys) {
    const valueA = a[key];
    const valueB = b[key];
    if (valueA === valueB) continue;
    if (
      typeof valueA === 'object' &&
      valueA !== null &&
      typeof valueB === 'object' &&
      valueB !== null
    ) {
      const nestedKeysA = Object.keys(valueA);
      const nestedKeysB = Object.keys(valueB);
      if (nestedKeysA.length !== nestedKeysB.length) return false;
      for (const nestedKey of nestedKeysA) {
        if (
          (valueA as Record<string, unknown>)[nestedKey] !==
          (valueB as Record<string, unknown>)[nestedKey]
        ) {
          return false;
        }
      }
      continue;
    }
    return false;
  }
  return true;
}

export function isStyleEqual(
  a: MarkdownStyle,
  b: MarkdownStyle,
  referenceKeys: readonly string[]
): boolean {
  for (const key of referenceKeys) {
    const subA = a[key as keyof MarkdownStyle];
    const subB = b[key as keyof MarkdownStyle];
    if (subA === subB) continue;
    if (!subA || !subB) return false;
    if (
      !isSubStyleEqual(
        subA as Record<string, unknown>,
        subB as Record<string, unknown>
      )
    ) {
      return false;
    }
  }
  return true;
}
