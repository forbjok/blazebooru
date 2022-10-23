import { ref } from "vue";
import { defineStore } from "pinia";
import axios from "axios";

import { useAuthStore } from "./auth";

import type { Tag, UpdateTag } from "@/models/api/tag";

export const useTagsStore = defineStore("tags", () => {
  const authStore = useAuthStore();

  const activeSearch = ref<string>("");

  const currentTags = ref<Tag[]>([]);

  function clearSearch() {
    activeSearch.value = "";
  }

  async function getTag(id: number) {
    const res = await axios.get<Tag>(`/api/tag/${id}`);
    const tag = res.data;

    const existingIndex = currentTags.value.findIndex((t) => t.id === tag.id);
    if (existingIndex) {
      currentTags.value[existingIndex] = tag;
    }

    return res.data;
  }

  async function fetchTags() {
    const res = await axios.get<Tag[]>("/api/tag");
    currentTags.value = res.data;
  }

  async function updateTag(id: number, update_tag: UpdateTag) {
    await axios.post(`/api/tag/${id}/update`, update_tag, {
      headers: await authStore.getAuthHeaders(),
    });

    return true;
  }

  async function refresh() {
    await searchTags(activeSearch.value);
  }

  async function searchTags(search: string) {
    activeSearch.value = search;

    await fetchTags();
  }

  async function initialize() {
    if (currentTags.value.length > 0) {
      return;
    }

    await searchTags("");
  }

  return {
    activeSearch,
    currentTags,
    clearSearch,
    getTag,
    updateTag,
    refresh,
    initialize,
  };
});
