# Block-level editing in the Markdown input (issue #359)

Adds in-editor rendering + toggling of paragraph-level blocks (headings first,
then lists) to `EnrichedMarkdownTextInput`, while keeping Markdown as the
serialization format. Closes the gap behind issue #359: the readonly renderer
(`EnrichedMarkdownText`) already renders headings/lists, but the editable input
only supported inline marks.

## Architecture recap

The editor keeps **plain text** in the platform text storage plus a list of
**inline** `ENRMFormattingRange` (type + range) in `ENRMFormattingStore`. Inline
marks are thin strategies keyed by `ENRMInputStyleType`. The serializer inserts
paired delimiters (`**`, `*`, …); the parser uses md4c to map Markdown → plain
text + inline ranges.

Blocks are fundamentally different from inline marks:

- They apply to **whole paragraphs/lines**, are **mutually exclusive** per
  paragraph, and serialize as **line prefixes** (`# `, `- `, `1. `, `- [ ] `),
  not paired delimiters.
- The serializer already noted this: block elements "are prefix-based and will
  need a separate serialization path."
- md4c already parses block structure; the input parser's `enter_block`/
  `leave_block` were no-ops with explicit TODOs anticipating block support.

## Model

Block kind is stored as a **custom attributed-string attribute**
(`ENRMBlockTypeAttributeName` → `ENRMInputBlockType`) on the paragraph's text.
TextKit/Android spans migrate attributes across edits, so the block kind
survives typing, deletion, and paste with no manual range bookkeeping — the same
reason inline marks aren't re-derived per keystroke. A transient
`_pendingBlockType` carries the kind for an empty line (no character holds the
attribute yet) into the next keystroke.

## Pipeline (iOS; Android mirrors)

| Concern | File | Change |
|---|---|---|
| Type + attribute | `ENRMInputBlockType.{h,m}` | enum, attribute name, `ENRMBlockRange` |
| Render | `ENRMInputFormatter` | per-paragraph base font (heading size+bold) via heading map; font runs keyed by (traits, heading level) |
| Toggle | `EnrichedMarkdownTextInput` | `toggleH1/2/3` set/clear the block attribute per line in the selected paragraph(s) |
| Typing | `syncTypingAttributesWithPendingStyles` | typing attributes carry heading font + block attribute |
| Enter | `handleTextChanged` | a newline ends a heading (Markdown headings are single-line) |
| State | `emitOnChangeState` | `h1/h2/h3` active flags from the cursor paragraph |
| Serialize | `ENRMMarkdownSerializer` | line-based prefix pass after inline serialization (preserves line structure) |
| Parse | `ENRMInputParser` | line-based post-pass strips `#{1,3} ` prefixes, remaps inline ranges via old→new index map, returns block ranges |
| API | codegen spec + JS wrapper | `toggleH1/2/3` commands; `h1/h2/h3` in `OnChangeStateEvent` + context-menu styleState |

## Lists (follow-up)

Lists reuse the same model with added bookkeeping: ordered-list numbering,
checkbox checked state, Enter continues/exits the list, Backspace outdents. The
readonly renderer's `ListMarkerDrawer` provides marker drawing to reuse.

## Line-height parity (#359 part 1)

Heading typography is derived from the base font. Aligning the editor's
paragraph line-height/spacing with the readonly renderer's `StyleConfig` closes
the "line-height collapses on edit" half of the issue.
