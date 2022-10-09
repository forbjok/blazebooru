<script setup lang="ts">
import { ref } from "vue";
import TagsEditor from "./TagsEditor.vue";

const emit = defineEmits<{
  (e: "search", tags: string[], exclude_tags: string[]): void;
}>();

const search = () => {
  emit("search", tags.value, exclude_tags.value);
};

const tags = ref<string[]>([]);
const exclude_tags = ref<string[]>([]);
</script>

<template>
  <div class="search-panel">
    <form class="search-form" @submit.prevent="search">
      <label>Search for tags</label>
      <TagsEditor v-model="tags" @submit-blank="search" />
      <label>Exclude</label>
      <TagsEditor v-model="exclude_tags" @submit-blank="search" />
      <input class="search-button" type="submit" value="Search" />
    </form>
  </div>
</template>

<style scoped lang="scss">
.search-panel {
  display: flex;
  flex-direction: column;
  gap: 1rem;

  padding: 1rem;
}

.search-form {
  display: flex;
  flex-direction: column;
  gap: 0.4rem;
}
</style>
