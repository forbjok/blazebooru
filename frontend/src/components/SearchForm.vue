<script setup lang="ts">
import { toRefs } from "vue";

import TagsEditor from "./TagsEditor.vue";

import type { Search } from "@/stores/main";

interface Props {
  modelValue: Search;
}

const props = defineProps<Props>();

const { modelValue: search } = toRefs(props);
</script>

<template>
  <div class="search-form">
    <label>Search for tags</label>
    <TagsEditor v-model="search.tags" />
    <label>Exclude</label>
    <TagsEditor v-model="search.exclude_tags" />
  </div>
</template>

<style scoped lang="scss">
.search-form {
  display: flex;
  flex-direction: column;
  gap: 0.4rem;
}
</style>
