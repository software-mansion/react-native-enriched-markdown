export const sampleMarkdownImageAspectRatio = `
# react-native-enriched-markdown image aspect ratio repro

This screen uses \`EnrichedMarkdownText\` directly with default configuration.

## Portrait image (2:3)

![Portrait](https://placehold.co/600x900/png?text=Portrait+600x900)

## Portrait image (3:5)

![Portrait](https://placehold.co/720x1200/png?text=Portrait+720x1200)

## Square image (1:1)

![Square](https://placehold.co/800x800/png?text=Square+800x800)

## Landscape image (16:9)

![Landscape](https://placehold.co/1280x720/png?text=Landscape+1280x720)

## Wide landscape (2:1)

![Wide](https://placehold.co/1200x600/png?text=Wide+1200x600)

## High-Resolution Image Test

The image below is loaded at full resolution (4000+ pixels wide) to test downsampling. Without downsampling, this single image would consume ~48 MB of memory during decode. With Phase 3 downsampling, it decodes at screen-width resolution instead.

![High-res forest aerial view](https://images.unsplash.com/photo-1542273917363-3b1817f69a2d?w=4000)

## Inline images in text

Here is an inline image ![tiny](https://placehold.co/100x100/png?text=I) inside a paragraph to verify inline images still work correctly with **bold** and *italic* text.
`;
