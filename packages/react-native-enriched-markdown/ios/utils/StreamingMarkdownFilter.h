#pragma once

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, ENRMTableStreamingMode) {
  ENRMTableStreamingModeHidden = 0,
  ENRMTableStreamingModeProgressive,
};

#ifdef __cplusplus
extern "C" {
#endif

NSString *ENRMRenderableMarkdownForStreaming(NSString *markdown, ENRMTableStreamingMode tableMode);

#ifdef __cplusplus
}
#endif

NS_ASSUME_NONNULL_END
