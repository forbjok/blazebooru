<script setup lang="ts">
import { toRefs } from "vue";
import { format, isSameDay, isSameYear, parseJSON } from "date-fns";

import CommentText from "./CommentText.vue";

import type { Comment } from "@/models/api/comment";

interface Props {
  comment: Comment;
  can_edit?: boolean;
}

const props = withDefaults(defineProps<Props>(), {
  can_edit: false,
});

const { comment } = toRefs(props);

const formatTime = (value: string): string => {
  const now = new Date();
  const time = parseJSON(value);

  if (isSameDay(now, time)) {
    // If time is today, omit the date
    return format(time, "HH:mm:ss");
  } else if (isSameYear(now, time)) {
    // If time is not today, but this year, include date without year
    return format(time, "MMM do, HH:mm:ss");
  }

  // If time is not this year, include full date with year
  return format(time, "MMM do yyyy, HH:mm:ss");
};
</script>

<template>
  <div class="post-comment">
    <div class="header">
      <span class="time" title="Timestamp">{{ formatTime(comment.created_at) }}</span>
      <span class="name" title="Poster">{{ comment.user_name || "Anonymous" }}</span>
      <button class="link-button">No.</button>
      <button class="link-button">{{ comment.id }}</button>
    </div>
    <div class="text">
      <CommentText :text="comment.comment" />
    </div>
  </div>
</template>

<style scoped lang="scss">
.post-comment {
  display: flex;
  flex-direction: column;

  background-color: var(--color-comment-background);

  max-width: 100%;

  .text {
    padding: 0.3rem;
  }
}

.header {
  flex-grow: 1;

  display: flex;
  flex-direction: row;
  gap: 0.4rem;

  background-color: var(--color-comment-header-background);
  border-bottom: 1px solid var(--color-comment-header-border);

  padding: 0.3rem;

  cursor: default;

  .time {
    vertical-align: top;
    text-align: right;
  }

  .name {
    vertical-align: top;
    text-align: right;
    color: var(--color-comment-username);
  }

  button {
    color: var(--color-faded-text);
  }
}
</style>
