<script setup lang="ts">
import { onMounted, ref, watch } from "vue";

import MainLayout from "@/components/MainLayout.vue";
import Posts from "@/components/post/Posts.vue";
import SearchForm from "@/components/post/SearchForm.vue";

import { useMainStore, type Search } from "@/stores/main";
import { onBeforeRouteUpdate, useRoute, useRouter, type LocationQueryValue } from "vue-router";

const route = useRoute();
const router = useRouter();

const mainStore = useMainStore();

const search = ref<Search>(mainStore.activeSearch);
const pageNumbers = mainStore.getPageNumbers(12);
const pageNumbersMobile = mainStore.getPageNumbers(4);

watch(
  search,
  (v) => {
    mainStore.searchPosts(v);
  },
  { deep: true }
);

onBeforeRouteUpdate(async (to) => {
  const page = parseInt((to.query.p as LocationQueryValue) || "");
  if (!page) {
    router.replace({ name: "browse", query: { p: mainStore.currentPage } });
    return;
  }

  await mainStore.loadPage(page);
});

onMounted(async () => {
  await mainStore.initializePosts();
  const page = parseInt((route.query.p as LocationQueryValue) || "");
  if (page) {
    mainStore.loadPage(page);
  } else {
    router.replace({ name: "browse", query: { p: mainStore.currentPage } });
  }
});

const includeTag = (tag: string) => {
  if (search.value.tags.includes(tag)) {
    return;
  }

  search.value.tags.push(tag);

  // Sort tags alphabetically
  search.value.tags.sort((a, b) => a.localeCompare(b));
};

const excludeTag = (tag: string) => {
  if (search.value.exclude_tags.includes(tag)) {
    return;
  }

  // If this tag is in the include tags, remove it from thereof
  // instead of adding it to exclude tags.
  if (search.value.tags.includes(tag)) {
    const tagIndex = search.value.tags.findIndex((t) => t === tag);
    search.value.tags.splice(tagIndex, 1);
    return;
  }

  search.value.exclude_tags.push(tag);

  // Sort tags alphabetically
  search.value.exclude_tags.sort((a, b) => a.localeCompare(b));
};
</script>

<template>
  <main :class="`theme-${mainStore.settings.theme}`">
    <MainLayout>
      <!-- Desktop -->
      <div class="layout desktop">
        <div class="side-panel">
          <SearchForm v-model="search" />
          <label>Tags:</label>
          <div class="tags">
            <div v-for="(t, i) of mainStore.currentTags" :key="i" class="tag">
              <button class="link-button" @click="includeTag(t)">+</button>
              <button class="link-button" @click="excludeTag(t)">-</button>
              <span class="tag-text" :class="{ included: search.tags.includes(t) }">{{ t }}</span>
            </div>
          </div>
        </div>
        <div class="content">
          <Posts v-if="mainStore.currentPosts" :posts="mainStore.currentPosts" />
          <div v-if="mainStore.pageCount > 1" class="pages">
            <router-link :to="{ name: 'browse', query: { p: 1 } }" class="page first" title="First page"
              >&lt;&lt;</router-link
            >
            [
            <router-link
              v-for="p in pageNumbers"
              :key="p"
              :to="{ name: 'browse', query: { p } }"
              class="page"
              :class="{ current: p === mainStore.currentPage }"
            >
              {{ p }}
            </router-link>
            ]
            <router-link :to="{ name: 'browse', query: { p: mainStore.pageCount } }" class="page last" title="Last page"
              >>></router-link
            >
          </div>
        </div>
      </div>

      <!-- Mobile -->
      <div class="layout mobile">
        <div class="content">
          <Posts v-if="mainStore.currentPosts" :posts="mainStore.currentPosts" />
        </div>
        <div class="search-panel">
          <div v-if="mainStore.pageCount > 1" class="pages">
            <router-link :to="{ name: 'browse', query: { p: 1 } }" class="page first" title="First page"
              >&lt;&lt;</router-link
            >
            [
            <router-link
              v-for="p in pageNumbersMobile"
              :key="p"
              :to="{ name: 'browse', query: { p } }"
              class="page"
              :class="{ current: p === mainStore.currentPage }"
            >
              {{ p }}
            </router-link>
            ]
            <router-link :to="{ name: 'browse', query: { p: mainStore.pageCount } }" class="page last" title="Last page"
              >>></router-link
            >
          </div>
          <SearchForm v-model="search" />
        </div>
      </div>
    </MainLayout>
  </main>
</template>

<style scoped lang="scss">
.layout.desktop {
  display: flex;
  flex-direction: row;

  height: 100%;

  .side-panel {
    flex-shrink: 1;

    display: flex;
    flex-direction: column;
    gap: 1rem;

    background-color: var(--color-panel-background);

    padding: 1rem;

    max-width: 300px;

    .tags {
      display: flex;
      flex-direction: column;
      gap: 0.4rem;

      overflow: hidden;

      .tag {
        display: flex;
        flex-direction: row;
        gap: 0.4rem;

        .tag-text {
          text-overflow: ellipsis;
          white-space: nowrap;
          overflow: hidden;

          &.included {
            color: var(--color-tag-included);
          }
        }
      }
    }
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
}

.layout.mobile {
  flex-direction: column;

  padding-bottom: 7rem;

  .search-panel {
    position: fixed;
    left: 0;
    bottom: 0;
    right: 0;

    background-color: var(--color-panel-background);

    padding: 0.5rem;
  }

  .pages {
    display: flex;
    flex-direction: row;
    align-items: center;
    justify-content: center;
    gap: 0.5rem;

    padding: 0.4rem;
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
