import { ref, computed } from "vue";
import { defineStore } from "pinia";
import { useStorage } from "@vueuse/core";
import axios from "axios";

import { useAuthStore } from "./auth";

import type { Post, PostInfo } from "@/models/api/post";
import { DEFAULT_SETTINGS, type Settings } from "@/models/settings";

export interface Search {
  tags: string[];
  exclude_tags: string[];

  post_count: number;
}

const POSTS_PER_PAGE = 50;
const PAGES_SHOWN = 13;
const HALF_PAGES_SHOWN = Math.floor(PAGES_SHOWN / 2);

export const useMainStore = defineStore("main", () => {
  const authStore = useAuthStore();

  const activeSearch = ref<Search>();
  const currentPage = ref(-1);
  const posts = ref<Post[]>([]);
  const settings = useStorage<Settings>("bb_settings", DEFAULT_SETTINGS);

  const pageCount = computed(() => Math.ceil((activeSearch.value?.post_count ?? 0) / POSTS_PER_PAGE));
  const pages = computed(() => {
    const pages: number[] = [];

    let first_page = Math.max(0, currentPage.value - HALF_PAGES_SHOWN);
    let last_page = Math.min(pageCount.value, currentPage.value + HALF_PAGES_SHOWN);

    const page_diff = last_page - first_page;
    if (page_diff < PAGES_SHOWN) {
      if (first_page === 0) {
        last_page = Math.min(pageCount.value, last_page + (PAGES_SHOWN - page_diff));
      } else {
        first_page = Math.max(0, first_page - (PAGES_SHOWN - page_diff));
      }
    }

    for (let i = first_page; i < last_page; ++i) {
      pages.push(i);
    }

    return pages;
  });

  function clearSearch() {
    activeSearch.value = undefined;
  }

  async function getPost(id: number) {
    const res = await axios.get<Post>(`/api/post/${id}`);

    return res.data;
  }

  async function fetchPosts(include_tags: string[], exclude_tags: string[], offset: number, limit: number) {
    const t = include_tags.join(",") || undefined;
    const e = exclude_tags.join(",") || undefined;

    const res = await axios.get<Post[]>("/api/post/search", {
      params: {
        t,
        e,
        offset,
        limit,
      },
    });

    return res.data;
  }

  async function getPostsCount(include_tags: string[], exclude_tags: string[]) {
    const t = include_tags.join(",") || undefined;
    const e = exclude_tags.join(",") || undefined;

    const res = await axios.get<number>("/api/post/count", {
      params: {
        t,
        e,
      },
    });

    return res.data;
  }

  async function uploadPost(info: PostInfo, file: File) {
    const formData = new FormData();

    formData.append("info", JSON.stringify(info));
    formData.append("file", file, file.name);

    const res = await axios.post<Post>("/api/post/upload", formData, {
      headers: await authStore.getAuthHeaders(),
    });

    return res.data;
  }

  async function loadPosts(offset: number) {
    const search = activeSearch.value;
    if (!search) {
      return;
    }

    posts.value = await fetchPosts(search.tags, search.exclude_tags, offset, POSTS_PER_PAGE);
  }

  async function loadPage(page: number) {
    // We are already on this page, do nothing.
    if (currentPage.value == page) {
      return;
    }

    currentPage.value = page;

    const offset = page * POSTS_PER_PAGE;
    await loadPosts(offset);
  }

  async function loadLastPage() {
    await loadPage(pageCount.value - 1);
  }

  async function searchPosts(tags: string[], exclude_tags: string[]) {
    const post_count = await getPostsCount(tags, exclude_tags);

    currentPage.value = -1;
    activeSearch.value = { tags, exclude_tags, post_count };

    await loadPage(0);
  }

  async function initializePosts() {
    if (activeSearch.value) {
      return;
    }

    await searchPosts([], []);
  }

  return {
    activeSearch,
    currentPage,
    pageCount,
    pages,
    posts,
    settings,
    clearSearch,
    getPost,
    initializePosts,
    loadPage,
    loadLastPage,
    searchPosts,
    uploadPost,
  };
});
