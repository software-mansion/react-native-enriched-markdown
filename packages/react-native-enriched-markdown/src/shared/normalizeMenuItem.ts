// English defaults are resolved here so native always receives concrete
// strings — call sites in iOS / Android can read the label without any
// fallback logic of their own.

// Not __DEV__-gated on purpose: deprecation warnings need to surface in
// staging/TestFlight/CI prod builds too.
const warned = new Set<string>();

export const warnOnce = (key: string, msg: string) => {
  if (warned.has(key)) return;
  warned.add(key);
  console.warn(msg);
};

export type NormalizedMenuItem = { enabled: boolean; label: string };

export const normalizeMenuItem = (
  raw: unknown,
  parentProp: string,
  field: string,
  defaultEnabled: boolean,
  defaultLabel: string
): NormalizedMenuItem => {
  if (raw === undefined)
    return { enabled: defaultEnabled, label: defaultLabel };
  if (typeof raw === 'boolean') {
    warnOnce(
      `${parentProp}.${field}`,
      `[react-native-enriched-markdown] ${parentProp}.${field} as a boolean is ` +
        `deprecated; use { enabled: ${raw} }. The boolean form will be removed in 0.8.`
    );
    return { enabled: raw, label: defaultLabel };
  }
  // Validate per leaf so an empty string stays an empty string (an emoji-only
  // item is a legitimate use case), while null / non-object / wrong-typed
  // fields fall back to defaults — `getBoolean` on the Android side throws on
  // non-booleans, and a null root would crash JS on property access.
  const obj =
    typeof raw === 'object' && raw !== null
      ? (raw as { enabled?: unknown; label?: unknown })
      : {};
  return {
    enabled: typeof obj.enabled === 'boolean' ? obj.enabled : defaultEnabled,
    label: typeof obj.label === 'string' ? obj.label : defaultLabel,
  };
};
