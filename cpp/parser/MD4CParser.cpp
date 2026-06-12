#include "MD4CParser.hpp"
#include "../md4c/md4c.h"
#include <cstring>
#include <vector>

namespace Markdown {

class MD4CParser::Impl {
public:
  std::shared_ptr<MarkdownASTNode> root;
  std::vector<std::shared_ptr<MarkdownASTNode>> nodeStack;
  std::string currentText;
  const char *inputText = nullptr;

  static const std::string ATTR_LEVEL;
  static const std::string ATTR_URL;
  static const std::string ATTR_TITLE;
  static const std::string ATTR_FENCE_CHAR;
  static const std::string ATTR_LANGUAGE;
  static const std::string ATTR_IS_TASK;
  static const std::string ATTR_TASK_CHECKED;

  void reset(size_t estimatedDepth) {
    root = std::make_shared<MarkdownASTNode>(NodeType::Document);
    nodeStack.clear();
    // Reserve based on estimated depth, with reasonable bounds
    // Typical markdown has 5-15 levels, but can go deeper with nested structures
    // Cap at 128 to avoid excessive memory for extreme cases
    nodeStack.reserve(std::min(estimatedDepth, static_cast<size_t>(128)));
    nodeStack.push_back(root);
    currentText.clear();
    currentText.reserve(256);
  }

  void flushText() {
    if (!currentText.empty() && !nodeStack.empty()) {
      auto textNode = std::make_shared<MarkdownASTNode>(NodeType::Text);
      textNode->content = std::move(currentText);
      nodeStack.back()->addChild(std::move(textNode));
      currentText.clear();
    }
  }

  void pushNode(std::shared_ptr<MarkdownASTNode> node) {
    flushText();
    if (node && !nodeStack.empty()) {
      nodeStack.back()->addChild(node);
      nodeStack.push_back(std::move(node));
    }
  }

  void popNode() {
    flushText();
    if (nodeStack.size() > 1) {
      nodeStack.pop_back();
    }
  }

  void addInlineNode(std::shared_ptr<MarkdownASTNode> node) {
    flushText();
    if (node && !nodeStack.empty()) {
      nodeStack.back()->addChild(node);
    }
  }

  std::string getAttributeText(const MD_ATTRIBUTE *attr) {
    if (!attr || attr->size == 0 || !attr->text)
      return {};

    // Use string constructor directly - let SSO handle small strings efficiently
    // Empty return {} avoids allocating empty string object
    return std::string(attr->text, attr->size);
  }

  static int enterBlock(MD_BLOCKTYPE type, void *detail, void *userdata) {
    if (!userdata)
      return 1;
    auto *impl = static_cast<Impl *>(userdata);

    switch (type) {
      case MD_BLOCK_DOC:
        // Document node already created in reset()
        break;

      case MD_BLOCK_P: {
        impl->pushNode(std::make_shared<MarkdownASTNode>(NodeType::Paragraph));
        break;
      }

      case MD_BLOCK_H: {
        auto node = std::make_shared<MarkdownASTNode>(NodeType::Heading);
        if (detail) {
          auto *h = static_cast<MD_BLOCK_H_DETAIL *>(detail);
          int level = static_cast<int>(h->level);
          // Clamp level to valid range (1-6)
          level = (level < 1) ? 1 : (level > 6) ? 6 : level;
          // Use char conversion for small integers (1-6)
          // Avoids std::to_string() allocation overhead
          char levelStr[2] = {static_cast<char>('0' + level), '\0'};
          node->setAttribute(ATTR_LEVEL, levelStr);
        }
        impl->pushNode(node);
        break;
      }

      case MD_BLOCK_QUOTE: {
        impl->pushNode(std::make_shared<MarkdownASTNode>(NodeType::Blockquote));
        break;
      }

      case MD_BLOCK_UL: {
        impl->pushNode(std::make_shared<MarkdownASTNode>(NodeType::UnorderedList));
        break;
      }

      case MD_BLOCK_OL: {
        impl->pushNode(std::make_shared<MarkdownASTNode>(NodeType::OrderedList));
        break;
      }

      case MD_BLOCK_LI: {
        auto node = std::make_shared<MarkdownASTNode>(NodeType::ListItem);
        if (detail) {
          auto *li = static_cast<MD_BLOCK_LI_DETAIL *>(detail);
          if (li->is_task) {
            node->setAttribute(ATTR_IS_TASK, "true");
            node->setAttribute(ATTR_TASK_CHECKED, (li->task_mark == 'x' || li->task_mark == 'X') ? "true" : "false");
          }
        }
        impl->pushNode(node);
        break;
      }

      case MD_BLOCK_CODE: {
        auto node = std::make_shared<MarkdownASTNode>(NodeType::CodeBlock);
        if (detail) {
          auto *codeDetail = static_cast<MD_BLOCK_CODE_DETAIL *>(detail);
          // Extract fence character (if fenced code block)
          if (codeDetail->fence_char != 0) {
            char fenceStr[2] = {static_cast<char>(codeDetail->fence_char), '\0'};
            node->setAttribute(ATTR_FENCE_CHAR, fenceStr);
          }
          // Extract language from lang attribute
          std::string lang = impl->getAttributeText(&codeDetail->lang);
          if (!lang.empty()) {
            node->setAttribute(ATTR_LANGUAGE, lang);
          }
        }
        impl->pushNode(node);
        break;
      }

      case MD_BLOCK_HR: {
        impl->pushNode(std::make_shared<MarkdownASTNode>(NodeType::ThematicBreak));
        break;
      }

      case MD_BLOCK_TABLE: {
        auto node = std::make_shared<MarkdownASTNode>(NodeType::Table);
        if (detail) {
          auto *tableDetail = static_cast<MD_BLOCK_TABLE_DETAIL *>(detail);
          node->setAttribute("colCount", std::to_string(tableDetail->col_count));
          node->setAttribute("headRowCount", std::to_string(tableDetail->head_row_count));
          node->setAttribute("bodyRowCount", std::to_string(tableDetail->body_row_count));
        }
        impl->pushNode(node);
        break;
      }

      case MD_BLOCK_THEAD: {
        impl->pushNode(std::make_shared<MarkdownASTNode>(NodeType::TableHead));
        break;
      }

      case MD_BLOCK_TBODY: {
        impl->pushNode(std::make_shared<MarkdownASTNode>(NodeType::TableBody));
        break;
      }

      case MD_BLOCK_TR: {
        impl->pushNode(std::make_shared<MarkdownASTNode>(NodeType::TableRow));
        break;
      }

      case MD_BLOCK_TH:
      case MD_BLOCK_TD: {
        auto node =
            std::make_shared<MarkdownASTNode>(type == MD_BLOCK_TH ? NodeType::TableHeaderCell : NodeType::TableCell);
        if (detail) {
          auto *tdDetail = static_cast<MD_BLOCK_TD_DETAIL *>(detail);
          const char *alignStr;
          switch (tdDetail->align) {
            case MD_ALIGN_LEFT:
              alignStr = "left";
              break;
            case MD_ALIGN_CENTER:
              alignStr = "center";
              break;
            case MD_ALIGN_RIGHT:
              alignStr = "right";
              break;
            default:
              alignStr = "default";
              break;
          }
          node->setAttribute("align", alignStr);
        }
        impl->pushNode(node);
        break;
      }

      default:
        // Other block types not yet implemented
        break;
    }

    return 0;
  }

  static int leaveBlock(MD_BLOCKTYPE type, void *detail, void *userdata) {
    (void)detail;
    if (!userdata)
      return 1;
    auto *impl = static_cast<Impl *>(userdata);

    if (type != MD_BLOCK_DOC && !impl->nodeStack.empty()) {
      impl->popNode();
    }

    return 0;
  }

  static int enterSpan(MD_SPANTYPE type, void *detail, void *userdata) {
    if (!userdata)
      return 1;
    auto *impl = static_cast<Impl *>(userdata);

    switch (type) {
      case MD_SPAN_A: {
        auto node = std::make_shared<MarkdownASTNode>(NodeType::Link);
        if (detail) {
          auto *linkDetail = static_cast<MD_SPAN_A_DETAIL *>(detail);
          std::string url = impl->getAttributeText(&linkDetail->href);
          if (!url.empty()) {
            node->setAttribute(ATTR_URL, url);
          }
        }
        impl->pushNode(node);
        break;
      }

      case MD_SPAN_STRONG: {
        impl->pushNode(std::make_shared<MarkdownASTNode>(NodeType::Strong));
        break;
      }

      case MD_SPAN_EM: {
        impl->pushNode(std::make_shared<MarkdownASTNode>(NodeType::Emphasis));
        break;
      }

      case MD_SPAN_U: {
        impl->pushNode(std::make_shared<MarkdownASTNode>(NodeType::Underline));
        break;
      }

      case MD_SPAN_CODE: {
        impl->pushNode(std::make_shared<MarkdownASTNode>(NodeType::Code));
        break;
      }

      case MD_SPAN_DEL: {
        impl->pushNode(std::make_shared<MarkdownASTNode>(NodeType::Strikethrough));
        break;
      }

      case MD_SPAN_IMG: {
        auto node = std::make_shared<MarkdownASTNode>(NodeType::Image);
        if (detail) {
          auto *imgDetail = static_cast<MD_SPAN_IMG_DETAIL *>(detail);
          std::string url = impl->getAttributeText(&imgDetail->src);
          if (!url.empty()) {
            node->setAttribute(ATTR_URL, url);
          }
          std::string title = impl->getAttributeText(&imgDetail->title);
          if (!title.empty()) {
            node->setAttribute(ATTR_TITLE, title);
          }
        }
        impl->pushNode(node);
        break;
      }

      case MD_SPAN_LATEXMATH: {
        impl->pushNode(std::make_shared<MarkdownASTNode>(NodeType::LatexMathInline));
        break;
      }

      case MD_SPAN_LATEXMATH_DISPLAY: {
        impl->pushNode(std::make_shared<MarkdownASTNode>(NodeType::LatexMathDisplay));
        break;
      }

      case MD_SPAN_SPOILER: {
        impl->pushNode(std::make_shared<MarkdownASTNode>(NodeType::Spoiler));
        break;
      }

      case MD_SPAN_SUPERSCRIPT: {
        impl->pushNode(std::make_shared<MarkdownASTNode>(NodeType::Superscript));
        break;
      }

      case MD_SPAN_SUBSCRIPT: {
        impl->pushNode(std::make_shared<MarkdownASTNode>(NodeType::Subscript));
        break;
      }

      case MD_SPAN_MARK: {
        impl->pushNode(std::make_shared<MarkdownASTNode>(NodeType::Highlight));
        break;
      }

      default:
        break;
    }

    return 0;
  }

  static int leaveSpan(MD_SPANTYPE type, void *detail, void *userdata) {
    (void)detail;
    if (!userdata)
      return 1;
    auto *impl = static_cast<Impl *>(userdata);

    if (!impl->nodeStack.empty()) {
      impl->popNode();
    }

    return 0;
  }

  static int text(MD_TEXTTYPE type, const MD_CHAR *text, MD_SIZE size, void *userdata) {
    if (!userdata || !text || size == 0)
      return 0;
    auto *impl = static_cast<Impl *>(userdata);

    // Handle soft/hard line breaks
    if (type == MD_TEXT_SOFTBR || type == MD_TEXT_BR) {
      auto brNode = std::make_shared<MarkdownASTNode>(NodeType::LineBreak);
      impl->addInlineNode(brNode);
      return 0;
    }

    // Handle text content (normal text, code text, LaTeX math, etc.)
    if (type == MD_TEXT_NORMAL || type == MD_TEXT_CODE || type == MD_TEXT_LATEXMATH) {
      impl->currentText.append(text, size);
    }

    return 0;
  }
};

namespace {

bool isDisplayMathNode(const MarkdownASTNode &node) {
  return node.type == NodeType::LatexMathDisplay;
}

bool isSeparatorNode(const MarkdownASTNode &node) {
  return node.type == NodeType::LineBreak ||
         (node.type == NodeType::Text && node.content.find_first_not_of(" \t\n\r") == std::string::npos);
}

// md4c treats $$...$$ as an inline span, so when display math appears on a line
// directly after text (no blank line), md4c merges them into a single Paragraph.
// This function finds the trailing run of LatexMathDisplay nodes (possibly
// interspersed with LineBreak / whitespace separators) at the end of a paragraph's
// children. Returns the index where the trailing run starts, or children.size()
// if there is nothing to promote.
size_t findTrailingDisplayMathRun(const std::vector<std::shared_ptr<MarkdownASTNode>> &children) {
  size_t trailingRunStart = children.size();
  bool hasDisplayMath = false;

  for (size_t j = children.size(); j > 0; --j) {
    auto &node = children[j - 1];
    if (isDisplayMathNode(*node)) {
      trailingRunStart = j - 1;
      hasDisplayMath = true;
    } else if (isSeparatorNode(*node) && hasDisplayMath) {
      trailingRunStart = j - 1;
    } else {
      break;
    }
  }

  return hasDisplayMath ? trailingRunStart : children.size();
}

// Collect only the LatexMathDisplay nodes from a range, skipping separators.
std::vector<std::shared_ptr<MarkdownASTNode>>
collectDisplayMathNodes(const std::vector<std::shared_ptr<MarkdownASTNode>> &children, size_t from) {
  std::vector<std::shared_ptr<MarkdownASTNode>> result;
  for (size_t j = from; j < children.size(); ++j) {
    if (isDisplayMathNode(*children[j]))
      result.push_back(children[j]);
  }
  return result;
}

// md4c wraps $$...$$ (display math) as inline spans inside a Paragraph. When they
// appear on consecutive lines without a blank separator, md4c merges them — along
// with any preceding text — into a single Paragraph with LineBreak nodes between them.
//
// This post-processing step walks the document's top-level children and promotes
// trailing LatexMathDisplay nodes out of their parent Paragraph so that the
// rendering layer sees them as top-level block elements.
//
// Two cases:
//  (a) Pure: every child is display math or a separator → replace paragraph entirely.
//  (b) Mixed: leading text followed by display math → keep text in the paragraph,
//      splice the display math nodes as siblings after it.
void promoteDisplayMathFromParagraphs(MarkdownASTNode &root) {
  auto &children = root.children;

  for (size_t i = 0; i < children.size();) {
    auto &paragraph = children[i];
    if (paragraph->type != NodeType::Paragraph || paragraph->children.empty()) {
      ++i;
      continue;
    }

    auto &paragraphChildren = paragraph->children;
    size_t trailingRunStart = findTrailingDisplayMathRun(paragraphChildren);

    if (trailingRunStart >= paragraphChildren.size()) {
      ++i;
      continue;
    }

    auto promoted = collectDisplayMathNodes(paragraphChildren, trailingRunStart);

    if (trailingRunStart == 0) {
      auto position = children.erase(children.begin() + static_cast<ptrdiff_t>(i));
      children.insert(position, promoted.begin(), promoted.end());
      i += promoted.size();
    } else {
      paragraphChildren.erase(paragraphChildren.begin() + static_cast<ptrdiff_t>(trailingRunStart),
                              paragraphChildren.end());
      while (!paragraphChildren.empty() && isSeparatorNode(*paragraphChildren.back())) {
        paragraphChildren.pop_back();
      }
      auto position = children.begin() + static_cast<ptrdiff_t>(i) + 1;
      children.insert(position, promoted.begin(), promoted.end());
      i += 1 + promoted.size();
    }
  }
}

} // anonymous namespace

MD4CParser::MD4CParser() : impl_(std::make_unique<Impl>()) {}

MD4CParser::~MD4CParser() = default;

std::shared_ptr<MarkdownASTNode> MD4CParser::parse(const std::string &markdown, const Md4cFlags &md4cFlags) {
  if (markdown.empty()) {
    return std::make_shared<MarkdownASTNode>(NodeType::Document);
  }

  // Estimate stack depth based on markdown size
  // Heuristic: ~1 nesting level per 500-1000 characters for typical markdown
  // This is a rough estimate - actual depth depends on structure, not just size
  // Base depth of 12 covers typical nested structures (blockquotes, future lists)
  size_t estimatedDepth = 12; // Base depth for small documents
  if (markdown.size() > 1000) {
    // Scale up for larger documents, but cap the growth
    estimatedDepth = std::min(static_cast<size_t>(12 + (markdown.size() / 1000)), static_cast<size_t>(64));
  }

  impl_->reset(estimatedDepth);
  impl_->inputText = markdown.c_str();

  unsigned flags = MD_FLAG_NOHTML | MD_FLAG_STRIKETHROUGH | MD_FLAG_TABLES | MD_FLAG_TASKLISTS | MD_FLAG_SPOILERS;
  if (md4cFlags.permissiveAutolinks) {
    flags |= MD_FLAG_PERMISSIVEAUTOLINKS;
  }
  if (md4cFlags.latexMath) {
    flags |= MD_FLAG_LATEXMATHSPANS;
  }
  if (md4cFlags.underline) {
    flags |= MD_FLAG_UNDERLINE;
  }
  if (md4cFlags.superscript) {
    flags |= MD_FLAG_SUPERSCRIPTS;
  }
  if (md4cFlags.subscript) {
    flags |= MD_FLAG_SUBSCRIPTS;
  }
  if (md4cFlags.highlight) {
    flags |= MD_FLAG_HIGHLIGHT;
  }

  // Configure MD4C parser with callbacks
  MD_PARSER parser = {
      0, // abi_version
      flags,   &Impl::enterBlock, &Impl::leaveBlock, &Impl::enterSpan, &Impl::leaveSpan, &Impl::text,
      nullptr, // debug_log
      nullptr  // syntax
  };

  // Parse the markdown
  int result = md_parse(markdown.c_str(), static_cast<MD_SIZE>(markdown.size()), &parser, impl_.get());

  if (result != 0) {
    // Parsing failed, return empty document
    return std::make_shared<MarkdownASTNode>(NodeType::Document);
  }

  impl_->flushText();

  if (impl_->root) {
    promoteDisplayMathFromParagraphs(*impl_->root);
  }

  return impl_->root ? impl_->root : std::make_shared<MarkdownASTNode>(NodeType::Document);
}

// Static member definitions
const std::string MD4CParser::Impl::ATTR_LEVEL = "level";
const std::string MD4CParser::Impl::ATTR_URL = "url";
const std::string MD4CParser::Impl::ATTR_TITLE = "title";
const std::string MD4CParser::Impl::ATTR_FENCE_CHAR = "fenceChar";
const std::string MD4CParser::Impl::ATTR_LANGUAGE = "language";
const std::string MD4CParser::Impl::ATTR_IS_TASK = "isTask";
const std::string MD4CParser::Impl::ATTR_TASK_CHECKED = "taskChecked";

} // namespace Markdown