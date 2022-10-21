<script setup lang="ts">
import { computed, toRefs } from "vue";

interface Props {
  tags: string[];
  actions?: boolean;
}

const props = withDefaults(defineProps<Props>(), {
  actions: false,
});

const emit = defineEmits<{
  (e: "delete", tag: string): void;
}>();

const { tags, actions } = toRefs(props);

const sortedTags = computed(() => {
  return [...tags.value].sort((a, b) => a.localeCompare(b));
});
</script>

<template>
  <div class="tags">
    <div v-for="t of sortedTags" :key="t" class="tag">
      <span class="tag-tag" :title="t">{{ t }}</span
      ><button
        v-if="actions"
        class="delete-button link-button"
        type="button"
        title="Delete"
        tabindex="-1"
        @click="emit('delete', t)"
      >
        x
      </button>
    </div>
  </div>
</template>

<style scoped lang="scss">
$thumbnail-size: 200px;

.tags {
  display: inline-flex;
  flex-direction: row;
  flex-wrap: wrap;
  gap: 0.2rem;

  overflow: hidden;

  max-width: 100%;
}

.tag {
  display: inline-flex;
  flex-direction: row;
  gap: 0.3rem;

  background-color: var(--color-tag-background);

  padding: 0.1rem 0.3rem;

  max-width: 100%;

  cursor: default;

  .tag-tag {
    text-overflow: ellipsis;
    white-space: nowrap;
    overflow: hidden;
  }
}

.include .tag {
  background-color: var(--color-tag-include-background);
}

.exclude .tag {
  background-color: var(--color-tag-exclude-background);
}
</style>
