<script setup lang="ts">
import { inject, toRefs } from "vue";

import type { Post } from "@/models/api/post";
import type { PathService } from "@/services/path";

const props = defineProps<{
  posts: Post[];
}>();

const { posts } = toRefs(props);

const path = inject<PathService>("path")!;
</script>

<template>
  <div class="posts">
    <a v-for="p in posts" :key="p.id" :href="`/post/${p.id}`" :title="p.title" class="post">
      <img :src="path.make_thumbnail_path(p)" />
    </a>
  </div>
</template>

<style scoped lang="scss">
$thumbnail-size: 200px;

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
  width: $thumbnail-size;
  height: $thumbnail-size;
}
</style>
