<script setup lang="ts">
import { inject, onMounted, ref, toRefs } from "vue";

import MainLayout from "@/components/MainLayout.vue";
import Post from "@/components/Post.vue";

import type { BlazeBooruApiService } from "@/services/api";
import type { Settings } from "@/models/settings";
import type { Post as PostModel } from "@/models/api/post";
import type { BlazeBooruAuthService } from "@/services/auth";

const props = defineProps<{
  id: number;
}>();

const { id } = toRefs(props);

const api = inject<BlazeBooruApiService>("api")!;
const auth = inject<BlazeBooruAuthService>("auth")!;
const settings = inject<Settings>("settings")!;

const post = ref<PostModel>();

onMounted(async () => {
  await auth.setup();

  const _post = await api.get_post(id.value);
  post.value = _post;
});
</script>

<template>
  <main :class="`theme-${settings.theme}`">
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
