import type { ReactNode } from 'react';
import type {
  ASTNode,
  NodeType,
  RendererCallbacks,
  RenderCapabilities,
  RendererMap,
} from '../types';
import type { MarkdownStyleInternal } from '../../types/MarkdownStyleInternal';
import type { Styles } from '../styles';
import { blockRenderers } from './BlockRenderers';
import { inlineRenderers } from './InlineRenderers';
import { listRenderers } from './ListRenderers';
import { tableRenderers } from './TableRenderers';

function nodeKey(node: ASTNode, index: number): string | number {
  if (node.type === 'ListItem' && node.attributes?.isTask === 'true') {
    const taskId = node.attributes.taskIndex ?? index;
    return `task-${taskId}-${node.attributes.taskChecked}`;
  }
  return index;
}

const RENDERERS: RendererMap = {
  ...blockRenderers,
  ...inlineRenderers,
  ...listRenderers,
  ...tableRenderers,
};

export interface RenderNodeProps {
  node: ASTNode;
  style: MarkdownStyleInternal;
  styles: Styles;
  callbacks: RendererCallbacks;
  capabilities: RenderCapabilities;
  parentType?: NodeType;
}

export function RenderNode({
  node,
  style,
  styles,
  callbacks,
  capabilities,
  parentType,
}: RenderNodeProps): ReactNode {
  const Renderer = RENDERERS[node.type];
  if (!Renderer) return null;

  const renderChildren = (childNode: ASTNode): ReactNode =>
    childNode.children?.map((child, index) => (
      <RenderNode
        key={nodeKey(child, index)}
        node={child}
        style={style}
        styles={styles}
        callbacks={callbacks}
        capabilities={capabilities}
        parentType={childNode.type}
      />
    )) ?? null;

  return (
    <Renderer
      node={node}
      style={style}
      styles={styles}
      parentType={parentType}
      callbacks={callbacks}
      capabilities={capabilities}
      renderChildren={renderChildren}
    />
  );
}
