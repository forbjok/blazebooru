<script setup lang="ts">
import { ref, toRefs } from "vue";

import { normalize_tag } from "@/utils/tag";

interface Props {
  button?: boolean;
}

const props = withDefaults(defineProps<Props>(), {
  button: false,
});

const emit = defineEmits<{
  (e: "enter", tags: string[], exclude_tags: string[]): void;
}>();

const { button } = toRefs(props);

const text = ref("");

const submit = () => {
  if (!text.value) {
    return;
  }

  const tags: string[] = [];
  const exclude_tags: string[] = [];

  const items = text.value.trim().split(",");

  for (const item of items) {
    let exclude = false;
    let tag = item.trim();
    if (tag.length === 0) {
      continue;
    }

    if (tag.charAt(0) === "-") {
      tag = tag.slice(1);
      exclude = true;
    }

    // Normalize tag
    tag = normalize_tag(tag);

    // If normalized tag is blank, skip it.
    if (tag.length === 0) {
      continue;
    }

    if (exclude) {
      exclude_tags.push(tag);
    } else {
      tags.push(tag);
    }
  }

  emit("enter", tags, exclude_tags);
  text.value = "";
};
</script>

<template>
  <form class="tags-entry" @submit.prevent="submit">
    <input type="text" v-model="text" placeholder="Tag(s)" title="Enter comma-separated list of tags" />
    <input v-if="button" type="submit" value="Add" />
  </form>
</template>

<style scoped lang="scss">
.tags-editor {
  display: flex;
  flex-direction: row;
  gap: 0.1rem;
}
</style>
