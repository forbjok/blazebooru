<script setup lang="ts">
import { inject, onMounted, ref } from "vue";

import MainLayout from "@/components/MainLayout.vue";
import Posts from "@/components/Posts.vue";

import type { BlazeBooruApiService } from "@/services/api";
import type { Settings } from "@/models/settings";
import type { Post } from "@/models/api/post";
import type { BlazeBooruAuthService } from "@/services/auth";

const api = inject<BlazeBooruApiService>("api")!;
const auth = inject<BlazeBooruAuthService>("auth")!;
const settings = inject<Settings>("settings")!;

const posts = ref<Post[]>();

onMounted(async () => {
  await auth.setup();

  const _posts = await api.get_posts();
  posts.value = _posts;
});
</script>

<template>
  <main :class="`theme-${settings.theme}`">
    <MainLayout>
      <Posts v-if="posts" :posts="posts" />
    </MainLayout>
  </main>
</template>

<style scoped lang="scss"></style>
