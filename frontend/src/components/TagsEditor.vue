<script setup lang="ts">
import { ref, toRefs } from "vue";

import Tags from "@/components/Tags.vue";
import { normalize_tag } from "@/utils/tag";

interface Props {
  modelValue: string[];
}

const props = defineProps<Props>();

const { modelValue: tags } = toRefs(props);

const text = ref("");

const addTag = (tag: string) => {
  tag = normalize_tag(tag);

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

const submitTag = () => {
  if (!text.value) {
    return;
  }

  addTag(text.value);
  text.value = "";
};
</script>

<template>
  <form class="tags-editor" @submit.prevent="submitTag">
    <Tags :tags="tags" :actions="true" @delete="deleteTag" />
    <div class="fields">
      <input type="text" v-model="text" placeholder="Tag" />
      <input type="submit" value="Add" />
    </div>
  </form>
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

.fields {
  display: flex;
  flex-direction: row;
  gap: 0.1rem;
}
</style>
