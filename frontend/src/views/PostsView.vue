<script setup lang="ts">
import { computed, inject, onMounted, ref } from "vue";

import MainLayout from "@/components/MainLayout.vue";
import Posts from "@/components/Posts.vue";

import type { BlazeBooruApiService } from "@/services/api";
import type { Settings } from "@/models/settings";
import type { PaginationStats, Post } from "@/models/api/post";
import type { BlazeBooruAuthService } from "@/services/auth";

const POSTS_PER_PAGE = 50;
const PAGES_SHOWN = 13;
const HALF_PAGES_SHOWN = Math.floor(PAGES_SHOWN / 2);

const api = inject<BlazeBooruApiService>("api")!;
const auth = inject<BlazeBooruAuthService>("auth")!;
const settings = inject<Settings>("settings")!;

const pagination_stats = ref<PaginationStats>();
const posts = ref<Post[]>();
const current_page = ref<number>(0);

const page_count = computed(() => Math.ceil((pagination_stats.value?.count ?? 0) / POSTS_PER_PAGE));
const pages = computed(() => {
  const pages: number[] = [];

  let first_page = Math.max(0, current_page.value - HALF_PAGES_SHOWN);
  let last_page = Math.min(page_count.value, current_page.value + HALF_PAGES_SHOWN);

  const page_diff = last_page - first_page;
  if (page_diff < PAGES_SHOWN) {
    if (first_page === 0) {
      last_page = Math.min(page_count.value, last_page + (PAGES_SHOWN - page_diff));
    } else {
      first_page = Math.max(0, first_page - (PAGES_SHOWN - page_diff));
    }
  }

  for (let i = first_page; i < last_page; ++i) {
    pages.push(i);
  }

  return pages;
});

onMounted(async () => {
  await auth.setup();

  const stats = await api.get_posts_pagination_stats();
  pagination_stats.value = stats;

  if (stats) {
    await loadPage(0);
  }
});

const loadPosts = async (offset: number) => {
  const _posts = await api.get_posts(offset, POSTS_PER_PAGE);
  posts.value = _posts;
};

const loadPage = async (page: number) => {
  const stats = pagination_stats.value;
  if (!stats) {
    return;
  }

  const offset = page * POSTS_PER_PAGE;
  await loadPosts(offset);

  current_page.value = page;
};
</script>

<template>
  <main :class="`theme-${settings.theme}`">
    <MainLayout>
      <Posts v-if="posts" :posts="posts" />
      <div v-if="page_count > 1" class="pages">
        <button class="page first" title="First page" @click="loadPage(0)">&lt;&lt;</button>
        [
        <button v-for="p in pages" :key="p" class="page" :class="{ current: p === current_page }" @click="loadPage(p)">
          {{ p + 1 }}
        </button>
        ]
        <button class="page last" title="Last page" @click="loadPage(page_count - 1)">>></button>
      </div>
    </MainLayout>
  </main>
</template>

<style scoped lang="scss">
.pages {
  position: fixed;
  left: 0;
  bottom: 1rem;
  right: 0;

  display: flex;
  flex-direction: row;
  justify-content: center;
  gap: 0.4rem;

  button {
    background: none;
    border: none;
    color: var(--color-link);

    padding: 0;

    &:enabled {
      cursor: pointer !important;
    }

    &:hover {
      color: var(--color-link-hover);
    }
  }

  .page {
    padding: 0 0.2rem;

    &.current {
      background-color: var(--color-current-page-background);

      font-size: 1.2rem;
    }
  }
}
</style>
