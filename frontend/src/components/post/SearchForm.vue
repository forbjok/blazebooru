<script setup lang="ts">
import { toRefs } from "vue";

import TagEntry from "@/components/tag/TagEntry.vue";
import Tags from "@/components/tag/Tags.vue";

import type { Search } from "@/stores/main";

interface Props {
  modelValue: Search;
}

const props = defineProps<Props>();

const { modelValue: search } = toRefs(props);

const tags = search.value.tags;
const exclude_tags = search.value.exclude_tags;

function removeItem<T>(array: T[], value: T) {
  const index = array.findIndex((v) => v === value);
  array.splice(index, 1);
}

const includeTag = (tag: string) => {
  // Don't add duplicate tags
  if (tags.includes(tag)) {
    return;
  }

  // If it's in exclude tags, remove it from there.
  if (exclude_tags.includes(tag)) {
    removeItem(exclude_tags, tag);
  }

  tags.push(tag);
};

const excludeTag = (tag: string) => {
  // Don't add duplicate tags
  if (exclude_tags.includes(tag)) {
    return;
  }

  // If it's in include tags, remove it from there.
  if (tags.includes(tag)) {
    removeItem(tags, tag);
  }

  exclude_tags.push(tag);
};

const enterTags = (tags: string[], exclude_tags: string[]) => {
  for (const t of tags) {
    includeTag(t);
  }

  for (const t of exclude_tags) {
    excludeTag(t);
  }
};
</script>

<template>
  <div class="search-form">
    <label>Search</label>
    <Tags :tags="search.tags" :actions="true" class="include" @delete="(t) => removeItem(tags, t)" />
    <Tags :tags="search.exclude_tags" :actions="true" class="exclude" @delete="(t) => removeItem(exclude_tags, t)" />
    <TagEntry @enter="enterTags" />
  </div>
</template>

<style scoped lang="scss">
.search-form {
  display: flex;
  flex-direction: column;
  gap: 0.4rem;
}
</style>
