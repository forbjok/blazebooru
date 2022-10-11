<script setup lang="ts">
import { ref, toRefs } from "vue";

import TagsEditor from "./TagsEditor.vue";

import type { Search } from "@/stores/main";

interface Props {
  initial_search?: Search;
}

const props = withDefaults(defineProps<Props>(), {
  initial_search: () => ({
    tags: [],
    exclude_tags: [],
  }),
});

const emit = defineEmits<{
  (e: "search", search: Search): void;
}>();

const { initial_search } = toRefs(props);

const performSearch = () => {
  emit("search", search.value);
};

const search = ref(initial_search.value);
</script>

<template>
  <div class="search-panel">
    <form class="search-form" @submit.prevent="performSearch">
      <label>Search for tags</label>
      <TagsEditor v-model="search.tags" @submit-blank="performSearch" />
      <label>Exclude</label>
      <TagsEditor v-model="search.exclude_tags" @submit-blank="performSearch" />
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
