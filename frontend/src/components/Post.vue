<script setup lang="ts">
import { computed, ref, toRefs } from "vue";

import Tags from "@/components/Tags.vue";

import type { Post } from "@/models/api/post";

import { make_image_path } from "@/utils/path";

interface Props {
  post: Post;
}

const props = defineProps<Props>();

const { post } = toRefs(props);

const expand_image = ref(false);
const url = computed(() => make_image_path(post.value));
</script>

<template>
  <div class="post">
    <div class="image" :class="{ expand: expand_image }" @click.prevent="expand_image = !expand_image">
      <a :href="url">
        <img :src="url" alt="Image" />
      </a>
    </div>
    <div class="actions">
      <a :href="url" :download="post.filename"><i class="fa-solid fa-download"></i> Download</a>
    </div>
    <div v-if="post.title" class="title">
      {{ post.title }}
    </div>
    <div v-if="post.title" class="user">Uploaded by: {{ post.user_name }}</div>
    <div v-if="post.tags">Tags: <Tags :tags="post.tags" /></div>
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
  a {
    display: block;
  }

  img {
    background-color: var(--color-post-background);

    padding: 0.2rem;
  }

  &:not(.expand) img {
    max-width: 90vw;
    max-height: 90vh;
  }
}
</style>
