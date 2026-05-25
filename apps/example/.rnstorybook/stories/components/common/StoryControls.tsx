import React from 'react';
import {
  Switch,
  Text,
  TextInput,
  TouchableOpacity,
  View,
  StyleSheet,
} from 'react-native';

export type StoryControl =
  | {
      prop: string;
      label: string;
      description?: string;
      type: 'boolean';
      default?: boolean;
    }
  | {
      prop: string;
      label: string;
      description?: string;
      type: 'select';
      options: string[] | { label: string; value: unknown }[];
      default?: unknown;
    }
  | {
      prop: string;
      label: string;
      description?: string;
      type: 'text';
      default?: string;
    };

export function setPath(
  obj: Record<string, unknown>,
  path: string,
  value: unknown
): Record<string, unknown> {
  const dot = path.indexOf('.');
  if (dot === -1) return { ...obj, [path]: value };
  const head = path.slice(0, dot);
  const tail = path.slice(dot + 1);
  return {
    ...obj,
    [head]: setPath((obj[head] as Record<string, unknown>) ?? {}, tail, value),
  };
}

export function initControlState(
  controls: StoryControl[]
): Record<string, unknown> {
  const state: Record<string, unknown> = {};
  for (const ctrl of controls) {
    if (ctrl.default !== undefined) state[ctrl.prop] = ctrl.default;
  }
  return state;
}

function resolveOptions(
  options: string[] | { label: string; value: unknown }[]
): { label: string; value: unknown }[] {
  if (options.length === 0) return [];
  return typeof options[0] === 'string'
    ? (options as string[]).map((s) => ({ label: s, value: s }))
    : (options as { label: string; value: unknown }[]);
}

type ControlRowProps = {
  control: StoryControl;
  value: unknown;
  onChange: (value: unknown) => void;
};

export function ControlRow({ control, value, onChange }: ControlRowProps) {
  const isBool = control.type === 'boolean';
  const isSelect = control.type === 'select';
  const isText = control.type === 'text';

  return (
    <View style={[styles.controlRow, isBool && styles.controlRowInline]}>
      <View style={styles.controlMeta}>
        <Text style={styles.controlLabel}>{control.label}</Text>
        {control.description ? (
          <Text style={styles.controlDesc}>{control.description}</Text>
        ) : null}
      </View>
      {isBool && <Switch value={Boolean(value)} onValueChange={onChange} />}
      {isSelect && (
        <SegmentedControl
          options={resolveOptions(control.options)}
          value={value ?? control.default}
          onChange={onChange}
        />
      )}
      {isText && (
        <TextInput
          style={styles.inlineInput}
          value={String(value ?? '')}
          onChangeText={onChange}
          autoCorrect={false}
          autoCapitalize="none"
        />
      )}
    </View>
  );
}

// ─── SegmentedControl ─────────────────────────────────────────────────────────

type SegmentedControlProps = {
  options: { label: string; value: unknown }[];
  value: unknown;
  onChange: (value: unknown) => void;
};

export function SegmentedControl({
  options,
  value,
  onChange,
}: SegmentedControlProps) {
  return (
    <View style={styles.segmented}>
      {options.map((opt, i) => {
        const active = opt.value === value;
        return (
          <TouchableOpacity
            key={String(opt.value)}
            style={[
              styles.segment,
              i === 0 && styles.segmentFirst,
              i === options.length - 1 && styles.segmentLast,
              active && styles.segmentActive,
            ]}
            onPress={() => onChange(opt.value)}
            activeOpacity={0.7}
          >
            <Text
              style={[styles.segmentText, active && styles.segmentTextActive]}
            >
              {opt.label}
            </Text>
          </TouchableOpacity>
        );
      })}
    </View>
  );
}

// ─── Styles ───────────────────────────────────────────────────────────────────

const styles = StyleSheet.create({
  controlRow: {
    gap: 6,
    paddingVertical: 2,
  },
  controlRowInline: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  controlMeta: {
    gap: 2,
    flex: 1,
  },
  controlLabel: {
    fontSize: 14,
    fontWeight: '500',
    color: '#222',
  },
  controlDesc: {
    fontSize: 12,
    color: '#777',
  },
  inlineInput: {
    borderWidth: 1,
    borderColor: '#ddd',
    borderRadius: 6,
    paddingHorizontal: 8,
    paddingVertical: 4,
    fontSize: 13,
    fontFamily: 'monospace',
    color: '#222',
    minWidth: 120,
  },
  segmented: {
    flexDirection: 'row',
    flexWrap: 'wrap',
  },
  segment: {
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderWidth: 1,
    borderColor: '#ddd',
    borderLeftWidth: 0,
    backgroundColor: '#fff',
  },
  segmentFirst: {
    borderLeftWidth: 1,
    borderTopLeftRadius: 6,
    borderBottomLeftRadius: 6,
  },
  segmentLast: {
    borderTopRightRadius: 6,
    borderBottomRightRadius: 6,
  },
  segmentActive: {
    backgroundColor: '#222',
    borderColor: '#222',
  },
  segmentText: {
    fontSize: 12,
    color: '#444',
  },
  segmentTextActive: {
    color: '#fff',
    fontWeight: '600',
  },
});
