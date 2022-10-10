<script setup lang="ts">
import { onMounted, ref, toRefs } from "vue";

import MainLayout from "@/components/MainLayout.vue";
import Post from "@/components/Post.vue";

import { useMainStore } from "@/stores/main";

import type { Post as PostModel } from "@/models/api/post";

const props = defineProps<{
  id: number;
}>();

const { id } = toRefs(props);

const mainStore = useMainStore();

const post = ref<PostModel>();

onMounted(async () => {
  post.value = await mainStore.getPost(id.value);
});
</script>

<template>
  <main :class="`theme-${mainStore.settings.theme}`">
    <MainLayout>
      <Post v-if="post" :post="post" />
    </MainLayout>
  </main>
</template>

<style scoped lang="scss">
main {
  padding: 2rem;
}
</style>
