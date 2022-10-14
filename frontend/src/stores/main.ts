import { ref, computed } from "vue";
import { defineStore } from "pinia";
import { useStorage } from "@vueuse/core";
import axios from "axios";

import { useAuthStore } from "./auth";

import type { PageInfo, Post, PostInfo, UpdatePost } from "@/models/api/post";
import { DEFAULT_SETTINGS, type Settings } from "@/models/settings";

export interface Search {
  tags: string[];
  exclude_tags: string[];
}

const POSTS_PER_PAGE = 28;
const PAGES_SHOWN = 13;
const HALF_PAGES_SHOWN = Math.floor(PAGES_SHOWN / 2);

const EMPTY_SEARCH = {
  tags: [],
  exclude_tags: [],
};

export const useMainStore = defineStore("main", () => {
  const authStore = useAuthStore();

  const activeSearch = ref<Search>(EMPTY_SEARCH);

  let calculatedPages: Record<number, PageInfo> = {};
  const lastPage = ref<PageInfo>();
  const currentPage = ref(-1);
  const currentPosts = ref<Post[]>([]);
  const settings = useStorage<Settings>("bb_settings", DEFAULT_SETTINGS);

  const pageCount = computed(() => lastPage.value?.no || 0);

  const currentTags = computed(() => {
    const tags: string[] = [];

    // Collect all distinct tags from every currently shown post
    for (const p of currentPosts.value) {
      tags.push(...p.tags.filter((tag) => tags.findIndex((t) => t === tag) < 0));
    }

    // Sort tags alphabetically
    tags.sort((a, b) => a.localeCompare(b));

    return tags;
  });

  const pages = computed(() => {
    const pages: number[] = [];

    let first_page = Math.max(1, currentPage.value - HALF_PAGES_SHOWN);
    let last_page = Math.min(pageCount.value, currentPage.value + HALF_PAGES_SHOWN);

    const page_diff = last_page - first_page;
    if (page_diff < PAGES_SHOWN) {
      if (first_page === 1) {
        last_page = Math.min(pageCount.value, last_page + (PAGES_SHOWN - page_diff));
      } else {
        first_page = Math.max(1, first_page - (PAGES_SHOWN - page_diff));
      }
    }

    for (let i = first_page; i <= last_page; ++i) {
      pages.push(i);
    }

    return pages;
  });

  function clearSearch() {
    activeSearch.value = EMPTY_SEARCH;
  }

  async function getPost(id: number) {
    const res = await axios.get<Post>(`/api/post/${id}`);

    return res.data;
  }

  async function fetchPosts(include_tags: string[], exclude_tags: string[], start_id: number) {
    const t = include_tags.join(",") || undefined;
    const e = exclude_tags.join(",") || undefined;

    const res = await axios.get<Post[]>("/api/post", {
      params: {
        t,
        e,
        sid: start_id,
        limit: POSTS_PER_PAGE,
      },
    });

    return res.data;
  }

  async function calculatePages(origin_page?: PageInfo, page_count?: number) {
    const search = activeSearch.value;
    if (!search) {
      return;
    }

    const t = search.tags.join(",") || undefined;
    const e = search.exclude_tags.join(",") || undefined;

    const res = await axios.get<PageInfo[]>("/api/post/pages", {
      params: {
        t,
        e,
        ppp: POSTS_PER_PAGE,
        pc: page_count || PAGES_SHOWN,
        opno: origin_page?.no,
        opsid: origin_page?.start_id,
      },
    });

    addCalculatedPages(res.data);
  }

  async function calculateLastPage() {
    const search = activeSearch.value;
    if (!search) {
      return;
    }

    const t = search.tags.join(",") || undefined;
    const e = search.exclude_tags.join(",") || undefined;

    const res = await axios.get<PageInfo>("/api/post/pages/last", {
      params: {
        t,
        e,
        ppp: POSTS_PER_PAGE,
      },
    });

    lastPage.value = res.data;
    addCalculatedPages([res.data]);
  }

  async function uploadPost(info: PostInfo, file: File) {
    const formData = new FormData();

    formData.append("info", JSON.stringify(info));
    formData.append("file", file, file.name);

    const res = await axios.post<Post>("/api/post/upload", formData, {
      headers: await authStore.getAuthHeaders(),
    });

    if (
      activeSearch.value.tags.every((t) => info.tags.includes(t)) &&
      activeSearch.value.exclude_tags.every((t) => !info.tags.includes(t))
    ) {
      await refresh();
    }

    return res.data;
  }

  async function updatePost(id: number, update_post: UpdatePost) {
    await axios.post<Post>(`/api/post/${id}/update`, update_post, {
      headers: await authStore.getAuthHeaders(),
    });

    return true;
  }

  async function loadPosts(start_id: number) {
    const search = activeSearch.value;
    if (!search) {
      return;
    }

    currentPosts.value = await fetchPosts(search.tags, search.exclude_tags, start_id);
  }

  function findNearestPage(page: number) {
    const nearestPages = (Object.values(calculatedPages) as unknown as PageInfo[]).sort(
      (a, b) => Math.abs(page - a.no) - Math.abs(page - b.no)
    );

    const nearestPage = nearestPages[0];
    if (!nearestPage) {
      return;
    }

    if (nearestPage.no < page) {
      const stopAtPage = nearestPages.find((pi) => pi.no > page);

      const toPageNo = stopAtPage && stopAtPage.no < page + PAGES_SHOWN ? stopAtPage.no : page + PAGES_SHOWN;
      return { nearestPage, length: toPageNo - nearestPage.no };
    } else {
      const startAtPage = nearestPages.find((pi) => pi.no < page);

      const fromPageNo = startAtPage && startAtPage.no > page - PAGES_SHOWN ? startAtPage.no : page - PAGES_SHOWN;
      return { nearestPage, length: fromPageNo - nearestPage.no };
    }
  }

  async function getPage(page: number) {
    const pageInfo = calculatedPages[page];
    if (pageInfo) {
      return pageInfo;
    }

    const nearestPage = findNearestPage(page);
    if (nearestPage) {
      const { nearestPage: originPage, length } = nearestPage;
      await calculatePages(originPage, length);
    } else {
      await calculatePages(undefined, page + PAGES_SHOWN);
    }

    return calculatedPages[page];
  }

  async function loadPage(page: number) {
    // We are already on this page, do nothing.
    if (currentPage.value == page) {
      return;
    }

    const pageInfo = await getPage(page);

    currentPage.value = page;
    await loadPosts(pageInfo.start_id);
  }

  async function loadLastPage() {
    await loadPage(pageCount.value);
  }

  function addCalculatedPages(pages: PageInfo[]) {
    for (const p of pages) {
      calculatedPages[p.no] = p;
    }
  }

  async function refresh() {
    await searchPosts(activeSearch.value);
  }

  async function searchPosts(search: Search) {
    activeSearch.value = search;
    currentPage.value = -1;
    lastPage.value = undefined;
    calculatedPages = [];
    currentPosts.value = [];

    await loadPage(1);
    await calculateLastPage();
  }

  async function initializePosts() {
    if (currentPosts.value.length > 0) {
      return;
    }

    await searchPosts(EMPTY_SEARCH);
  }

  return {
    activeSearch,
    currentPage,
    pageCount,
    pages,
    currentPosts,
    currentTags,
    settings,
    clearSearch,
    getPost,
    initializePosts,
    loadPage,
    loadLastPage,
    searchPosts,
    uploadPost,
    updatePost,
  };
});
