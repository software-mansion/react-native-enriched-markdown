import React from 'react';
import { EnrichedMarkdownTextStory } from '../EnrichedMarkdownTextStory';
import { storyMeta } from '../shared/storyMeta';
import {
  githubFlavorArgTypes,
  taskListStyledDefaults,
  type TaskListStyleControls,
  numberControl,
} from '../shared/storybookMarkdownStyles';
import {
  splitStyleControls,
  toTaskListStyle,
} from '../shared/storybookStyleBuilders';
import type { StoryArgs, TextStory } from '../shared/storyTypes';

const MARKDOWN = `- [x] Dice 2 onions, 3 celery stalks, and parsnips
- [x] Add vegetables to the pot
- [ ] Add ground pork and beef
- [ ] Saute for 10 minutes
- [ ] Pour in passata and simmer for 1 hour
- [x] Boil spaghetti pasta
- [ ] Mix everything and serve`;

const NESTED_MARKDOWN = `- [x] Buy groceries
  - [x] Vegetables
  - [ ] Fruit
- [ ] Cook dinner
  - [x] Prep ingredients
  - [ ] Serve
- [x] Wash dishes`;

const argTypes = {
  ...githubFlavorArgTypes('Task lists require flavor="github" (GFM).'),
  checkedColor: {
    control: 'color',
    description: 'markdownStyle.taskList.checkedColor',
  },
  borderColor: {
    control: 'color',
    description: 'markdownStyle.taskList.borderColor',
  },
  checkboxSize: numberControl('markdownStyle.taskList.checkboxSize', {
    min: 12,
    max: 28,
    step: 1,
  }),
  checkboxBorderRadius: numberControl(
    'markdownStyle.taskList.checkboxBorderRadius',
    { min: 0, max: 12, step: 1 }
  ),
  checkmarkColor: {
    control: 'color',
    description: 'markdownStyle.taskList.checkmarkColor',
  },
  checkedTextColor: {
    control: 'color',
    description: 'markdownStyle.taskList.checkedTextColor',
  },
  checkedStrikethrough: {
    control: 'boolean',
    description: 'markdownStyle.taskList.checkedStrikethrough',
  },
  onTaskListItemPress: { action: 'onTaskListItemPress' },
};

function renderTaskList(
  title: string,
  description: string,
  args: StoryArgs<TaskListStyleControls>
) {
  const { controls, rest } = splitStyleControls(args, taskListStyledDefaults);
  return (
    <EnrichedMarkdownTextStory
      title={title}
      description={description}
      {...rest}
      style={{ taskList: toTaskListStyle(controls) }}
    />
  );
}

const taskListStoryBase = {
  argTypes,
  args: {
    flavor: 'github' as const,
    ...taskListStyledDefaults,
  },
};

export default storyMeta('Block', 'Task List');

export const Default: TextStory<TaskListStyleControls> = {
  ...taskListStoryBase,
  args: {
    ...taskListStoryBase.args,
    markdown: MARKDOWN,
  },
  render: (args) =>
    renderTaskList(
      'Task List',
      'GFM task lists. Tap checkboxes to fire onTaskListItemPress (Actions panel). Use the controls to tune markdownStyle.taskList.',
      args
    ),
};

export const Nested: TextStory<TaskListStyleControls> = {
  ...taskListStoryBase,
  args: {
    ...taskListStoryBase.args,
    markdown: NESTED_MARKDOWN,
  },
  render: (args) =>
    renderTaskList(
      'Nested Task List',
      'Nest task items with indentation. Tap checkboxes to fire onTaskListItemPress (Actions panel).',
      args
    ),
};
