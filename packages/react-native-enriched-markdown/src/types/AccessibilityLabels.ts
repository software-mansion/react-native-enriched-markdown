/**
 * Strings spoken by VoiceOver (iOS) / TalkBack (Android) when navigating
 * the rendered markdown.
 *
 * Every key is optional — when omitted, defaults from
 * `accessibilityLabelDefaults.ts` are applied on the JS side before being
 * forwarded to native. Native code can rely on every field being a concrete
 * string at the point it is consumed.
 *
 * **Placeholder syntax.** Where a label has dynamic content, the default uses
 * `{n}` (count / index, 1-based), `{content}` (resolved cell text or similar),
 * or `{latex}` (math source). Translations must preserve the placeholder names
 * exactly — native code substitutes them at speak time.
 *
 * **No plurals.** Defaults intentionally use the cardinal form (`"Row 2"`,
 * `"List item 2"`) instead of ordinals or count-aware variants. Screen readers
 * already announce numbers locale-appropriately, and a single template avoids
 * the per-language plural rules (en `1/2+`, pl `1/2-4/5+`, ar `0/1/2/3-10/11-99/100+`, …).
 *
 * The shape is split into logical sub-groups so that consumers can override
 * just the announcements that matter to them without re-declaring the rest.
 */
export interface AccessibilityLabels {
  /** Labels spoken for list items. iOS + Android. */
  list?: {
    /**
     * Default: `"Bullet point"`.
     * TODO: wire through to native — currently hardcoded in
     * `MarkdownAccessibilityElementBuilder.m::formatListAnnouncement:` and
     * `MarkdownAccessibilityHelper.kt::listAnnouncement`.
     */
    bulletPoint?: string;
    /**
     * Default: `"Nested bullet point"`. Spoken when the bullet is inside another list.
     * TODO: wire through to native (same call sites as `bulletPoint`).
     */
    nestedBulletPoint?: string;
    /**
     * Default: `"List item {n}"`. `{n}` → 1-based item number.
     * TODO: wire through to native (same call sites as `bulletPoint`).
     */
    orderedItem?: string;
    /**
     * Default: `"Nested list item {n}"`. `{n}` → 1-based item number.
     * TODO: wire through to native (same call sites as `bulletPoint`).
     */
    nestedOrderedItem?: string;
  };

  /** Labels appended for content inside a blockquote. iOS + Android. */
  blockquote?: {
    /** Default: `"Blockquote"`. Spoken for top-level blockquote content. */
    quote?: string;
    /** Default: `"Nested blockquote"`. Spoken for content nested inside another blockquote. */
    nestedQuote?: string;
  };

  /** Labels spoken for tables. iOS only — Android currently does not vend per-row a11y. */
  table?: {
    /**
     * Default: `"Row {n}: {content}"`. `{n}` → 1-based row index,
     * `{content}` → comma-joined cell texts.
     * TODO: wire through to native — currently hardcoded in
     * `TableContainerView.m` row accessibility label.
     */
    row?: string;
  };

  /** Labels spoken for math equations. iOS only — Android currently does not announce math. */
  math?: {
    /**
     * Default: `"Math: {latex}"`. `{latex}` → equation source.
     * TODO: wire through to native — currently hardcoded in
     * `ENRMMathContainerView.m::accessibilityLabel`.
     */
    equation?: string;
  };

  /**
   * Labels for the VoiceOver rotor (the secondary jump-by-type navigator on iOS).
   * iOS only — Android has no rotor concept.
   */
  rotor?: {
    /**
     * Default: `"Headings"`.
     * TODO: wire through to native — currently hardcoded in
     * `MarkdownAccessibilityElementBuilder.m::createHeadingRotorWithElements:`.
     */
    headings?: string;
    /**
     * Default: `"Links"`.
     * TODO: wire through to native — currently hardcoded in
     * `MarkdownAccessibilityElementBuilder.m::createLinkRotorWithElements:`.
     */
    links?: string;
    /**
     * Default: `"Images"`.
     * TODO: wire through to native — currently hardcoded in
     * `MarkdownAccessibilityElementBuilder.m::createImageRotorWithElements:`.
     */
    images?: string;
  };
}

/**
 * Fully-populated counterpart of `AccessibilityLabels` — every leaf field is a
 * concrete string. Produced by `resolveAccessibilityLabels()` and what native
 * code should be wired to consume.
 */
export interface ResolvedAccessibilityLabels {
  list: {
    bulletPoint: string;
    nestedBulletPoint: string;
    orderedItem: string;
    nestedOrderedItem: string;
  };
  blockquote: {
    quote: string;
    nestedQuote: string;
  };
  table: {
    row: string;
  };
  math: {
    equation: string;
  };
  rotor: {
    headings: string;
    links: string;
    images: string;
  };
}
