#include "MD4CParser.hpp"
#include <jni.h>
#include <string>

using namespace Markdown;

extern "C" JNIEXPORT jint JNICALL Java_com_swmansion_enriched_markdown_parser_Parser_nativeParseNodeCount(
    JNIEnv *env, jobject /* thiz */, jstring markdown) {
  const char *markdownChars = env->GetStringUTFChars(markdown, nullptr);
  if (markdownChars == nullptr) {
    return 0;
  }

  std::string markdownString(markdownChars);
  env->ReleaseStringUTFChars(markdown, markdownChars);

  if (markdownString.empty()) {
    return 0;
  }

  MD4CParser parser;
  auto root = parser.parse(markdownString);
  if (root == nullptr) {
    return 0;
  }

  return static_cast<jint>(root->children.size());
}
