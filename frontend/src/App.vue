<script setup lang="ts">
import { computed, onBeforeMount, ref } from "vue";
import { RouterView } from "vue-router";

import { useMainStore } from "./stores/main";

import Loading from "@/components/common/Loading.vue";

const isInitialized = ref(false);
const isLoading = ref(true);
const errorMessage = ref<string>();

const mainStore = useMainStore();

const themeClass = computed(() => `theme-${mainStore.settings.theme}`);

onBeforeMount(async () => {
  try {
    await mainStore.isInitialized();

    isInitialized.value = true;
  } catch (err) {
    errorMessage.value = err as string;
  }

  isLoading.value = false;
});
</script>

<template>
  <RouterView v-if="isInitialized" :class="themeClass" />
  <main v-if="!isInitialized" :class="themeClass">
    <Loading class="loading" :is-loading="isLoading" :error-message="errorMessage" />
  </main>
</template>

<style scoped lang="scss">
@media only screen and (max-width: 480px) {
  main {
    max-width: 100vw;
  }
}
</style>
