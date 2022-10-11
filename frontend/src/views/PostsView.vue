<script setup lang="ts">
import { onMounted } from "vue";

import MainLayout from "@/components/MainLayout.vue";
import Posts from "@/components/Posts.vue";
import SearchPanel from "../components/SearchPanel.vue";

import { useMainStore } from "@/stores/main";

const mainStore = useMainStore();

onMounted(async () => {
  await mainStore.initializePosts();
});
</script>

<template>
  <main :class="`theme-${mainStore.settings.theme}`">
    <MainLayout>
      <div class="layout">
        <SearchPanel :initial_search="mainStore.activeSearch" class="side-panel" @search="mainStore.searchPosts" />
        <div class="content">
          <Posts v-if="mainStore.posts" :posts="mainStore.posts" />
          <div v-if="mainStore.pageCount > 1" class="pages">
            <button class="page first link-button" title="First page" @click="mainStore.loadPage(1)">&lt;&lt;</button>
            [
            <button
              v-for="p in mainStore.pages"
              :key="p"
              class="page link-button"
              :class="{ current: p === mainStore.currentPage }"
              @click="mainStore.loadPage(p)"
            >
              {{ p }}
            </button>
            ]
            <button class="page last link-button" title="Last page" @click="mainStore.loadLastPage()">>></button>
          </div>
        </div>
      </div>
    </MainLayout>
  </main>
</template>

<style scoped lang="scss">
.layout {
  display: flex;
  flex-direction: row;

  height: 100%;
}

.side-panel {
  flex-shrink: 1;

  background-color: var(--color-panel-background);
}

.content {
  flex-grow: 1;

  padding-bottom: 3rem;
}

.pages {
  position: fixed;
  left: 50%;
  bottom: 1rem;

  display: flex;
  flex-direction: row;
  align-items: center;
  gap: 0.4rem;

  background-color: var(--color-pages-background);

  padding: 0.2rem;

  transform: translateX(-50%);

  .page {
    padding: 0 0.2rem;

    &.current {
      background-color: var(--color-current-page-background);

      font-size: 1.2rem;
    }
  }
}
</style>
