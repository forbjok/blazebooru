<script setup lang="ts">
import { computed, inject, toRefs } from "vue";

import type { Post } from "@/models/api/post";
import type { PathService } from "@/services/path";

interface Props {
  post: Post;
}

const props = defineProps<Props>();

const { post } = toRefs(props);

const path = inject<PathService>("path")!;

const url = computed(() => path.make_image_path(post.value));
</script>

<template>
  <div class="post">
    <div v-if="post.title" class="title">
      {{ post.title }}
    </div>
    <div class="actions">
      <a :href="url" :download="post.filename"><i class="fa-solid fa-download"></i> Download</a>
    </div>
    <div class="image">
      <a :href="url">
        <img :src="url" alt="Image" />
      </a>
    </div>
    <div v-if="post.title" class="user">Uploaded by: {{ post.user_name }}</div>
    <div v-if="post.description" class="description">
      <div class="header">Description</div>
      <div class="text">{{ post.description }}</div>
    </div>
  </div>
</template>

<style scoped lang="scss">
.post {
  display: flex;
  flex-direction: column;
  align-items: start;
  gap: 0.5rem;
}

.title {
  font-size: 2rem;
}

.description {
  display: flex;
  flex-direction: column;

  background-color: var(--color-description-background);

  max-width: 100%;

  .header {
    background-color: var(--color-description-header-background);

    padding: 0.3rem;
  }

  .text {
    padding: 0.4rem;
  }
}

.image {
  display: flex;
  flex-direction: column;
  align-items: start;
  gap: 0.5rem;

  max-width: 100%;

  img {
    background-color: var(--color-post-background);
    padding: 1rem;

    object-fit: cover;
  }
}
</style>
