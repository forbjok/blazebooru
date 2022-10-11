<script setup lang="ts">
import { computed, onMounted, ref, toRefs } from "vue";

import MainLayout from "@/components/MainLayout.vue";
import Post from "@/components/Post.vue";

import { useMainStore } from "@/stores/main";

import type { Post as PostModel, UpdatePost } from "@/models/api/post";
import { useAuthStore } from "@/stores/auth";

const props = defineProps<{
  id: number;
}>();

const { id } = toRefs(props);

const authStore = useAuthStore();
const mainStore = useMainStore();

const post = ref<PostModel>();

const can_edit = computed(() => authStore.userProfile?.id === post.value?.user_id);

onMounted(async () => {
  await fetchPost();
});

const fetchPost = async () => {
  post.value = await mainStore.getPost(id.value);
};

const updatePost = async (update_post: UpdatePost) => {
  if (!post.value) {
    return;
  }

  await mainStore.updatePost(post.value.id, update_post);
  await fetchPost();
};
</script>

<template>
  <main :class="`theme-${mainStore.settings.theme}`">
    <MainLayout>
      <Post v-if="post" :post="post" :can_edit="can_edit" @update="updatePost" />
    </MainLayout>
  </main>
</template>

<style scoped lang="scss">
main {
  padding: 2rem;
}
</style>
