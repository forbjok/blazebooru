<script setup lang="ts">
import { toRefs } from "vue";

import Tags from "@/components/Tags.vue";
import TagEntry from "./TagEntry.vue";

interface Props {
  modelValue: string[];
}

const props = defineProps<Props>();

const { modelValue: tags } = toRefs(props);

const addTag = (tag: string) => {
  // Don't add blank tag
  if (tag.length === 0) {
    return;
  }

  // Don't add duplicate tags
  if (tags.value.includes(tag)) {
    return;
  }

  tags.value.push(tag);
};

const deleteTag = (tag: string) => {
  const index = tags.value.findIndex((t) => t === tag);
  tags.value.splice(index, 1);
};

const enterTags = (tags: string[], exclude_tags: string[]) => {
  for (const t of tags) {
    addTag(t);
  }

  for (const t of exclude_tags) {
    deleteTag(t);
  }
};
</script>

<template>
  <div class="tags-editor">
    <Tags :tags="tags" :actions="true" @delete="deleteTag" />
    <TagEntry :button="true" @enter="enterTags" />
  </div>
</template>

<style scoped lang="scss">
.tags-editor {
  display: flex;
  flex-direction: column;
  align-items: start;
  gap: 0.2rem;

  overflow: hidden;

  max-width: 100%;
}
</style>
