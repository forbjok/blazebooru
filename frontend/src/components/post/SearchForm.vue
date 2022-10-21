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

function removeItem<T>(array: T[], value: T) {
  const index = array.findIndex((v) => v === value);
  array.splice(index, 1);
}

const includeTag = (tag: string) => {
  const _search = search.value;

  // Don't add duplicate tags
  if (_search.tags.includes(tag)) {
    return;
  }

  // If it's in exclude tags, remove it from there.
  if (_search.exclude_tags.includes(tag)) {
    removeItem(_search.exclude_tags, tag);
  }

  _search.tags.push(tag);
};

const excludeTag = (tag: string) => {
  const _search = search.value;

  // Don't add duplicate tags
  if (_search.exclude_tags.includes(tag)) {
    return;
  }

  // If it's in include tags, remove it from there.
  if (_search.tags.includes(tag)) {
    removeItem(_search.tags, tag);
  }

  _search.exclude_tags.push(tag);
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
    <TagEntry @enter="enterTags" />
    <Tags :tags="search.tags" :actions="true" class="include" @delete="(t) => removeItem(search.tags, t)" />
    <Tags
      :tags="search.exclude_tags"
      :actions="true"
      class="exclude"
      @delete="(t) => removeItem(search.exclude_tags, t)"
    />
  </div>
</template>

<style scoped lang="scss">
.search-form {
  display: flex;
  flex-direction: column;
  gap: 0.4rem;
}
</style>
