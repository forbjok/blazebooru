<script setup lang="ts">
import { toRefs } from "vue";

const props = defineProps<{
  isLoading: boolean;
  errorMessage?: string;
}>();

const { isLoading, errorMessage } = toRefs(props);
</script>

<template>
  <div class="loading">
    <div v-show="isLoading" class="loading-text">LOADING</div>
    <div v-show="errorMessage" class="error-text">{{ errorMessage }}</div>
  </div>
</template>

<style scoped lang="scss">
.loading {
  font-size: 1.4rem;

  padding: 2rem;

  text-align: center;

  .loading-text {
    color: var(--color-default-text);
  }

  .error-text {
    color: var(--color-error-text);
  }
}
</style>
