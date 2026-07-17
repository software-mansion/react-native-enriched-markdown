# Image Caching

Images in Markdown content are loaded, cached, and reused automatically — no configuration required.

## Cache Layers

The library uses a three-tier caching strategy on both platforms:

| Layer | Android | iOS | Size |
|---|---|---|---|
| **Originals (memory)** | `LruCache` | `NSCache` | 20 MB |
| **Processed variants (memory)** | `LruCache` | `NSCache` | 30 MB |
| **Disk** | OkHttp `Cache` | `NSURLCache` | 100 MB |

- **Original cache** stores decoded images keyed by URL. On Android, large images are downsampled to screen width during decode to reduce peak memory.
- **Processed cache** stores scaled and clipped variants keyed by URL + dimensions + border radius, so repeated layouts with the same geometry skip all image processing.
- **Disk cache** persists raw HTTP responses across app launches, respecting standard HTTP cache headers.

## Request Headers

When `imageRequestHeaders` is set, the headers become part of the cache identity for both memory tiers and for request deduplication: the same URL requested with different headers is fetched and cached separately, and changing the prop re-fetches the images.

One caveat: the disk cache is managed by the HTTP stack (OkHttp / `NSURLCache`) and keys responses by URL alone. A response fetched with one set of headers can be served from disk for a request with different headers, subject to standard HTTP caching semantics (`Cache-Control`, `Vary`).

## Request Deduplication

When multiple components request the same image URL simultaneously (e.g. during a re-render), only one network request is made. All pending callbacks are coalesced and dispatched together once the download completes.

## Instance Reuse

`ImageSpan` (Android) and `ENRMImageAttachment` (iOS) instances are reused across re-renders for the same URL, avoiding redundant object allocation and image reloading.
