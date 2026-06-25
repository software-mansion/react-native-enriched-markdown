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
  const obj = raw as { enabled?: boolean; label?: string };
  return {
    enabled: obj.enabled ?? defaultEnabled,
    label: obj.label ?? defaultLabel,
  };
};
