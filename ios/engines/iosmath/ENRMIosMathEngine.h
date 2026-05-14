#pragma once
#import "ENRMFeatureFlags.h"
#import "ENRMMathEngine.h"

#if ENRICHED_MARKDOWN_MATH

NS_ASSUME_NONNULL_BEGIN

/// iosMath-backed implementation of `ENRMMathEngine`. Selected at build time
/// when `ENRICHED_MARKDOWN_MATH_ENGINE` is unset or `iosmath` (the default).
/// Behaves identically to the previous inline iosMath usage so existing
/// apps see no change after the engine abstraction lands.
@interface ENRMIosMathEngine : NSObject <ENRMMathEngine>
@end

NS_ASSUME_NONNULL_END

#endif
