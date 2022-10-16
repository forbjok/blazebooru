<script setup lang="ts">
import { toRefs } from "vue";

import type { Post } from "@/models/api/post";

import { make_thumbnail_path } from "@/utils/path";

const props = defineProps<{
  posts: Post[];
}>();

const { posts } = toRefs(props);
</script>

<template>
  <div class="posts">
    <router-link
      v-for="p in posts"
      :key="p.id"
      :to="{ name: 'post', params: { id: p.id } }"
      :title="p.title"
      class="post"
    >
      <img :src="make_thumbnail_path(p)" />
    </router-link>
  </div>
</template>

<style scoped lang="scss">
.posts {
  display: flex;
  flex-direction: row;
  flex-wrap: wrap;
  gap: 1rem;

  padding: 1rem;
}

.post {
  display: flex;
  align-items: center;
  justify-content: center;

  background-color: var(--color-post-background);
  width: var(--thumbnail-size);
  height: var(--thumbnail-size);

  img {
    max-width: var(--thumbnail-size);
    max-height: var(--thumbnail-size);
  }
}
</style>
