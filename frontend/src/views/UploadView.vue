<script setup lang="ts">
import { ref } from "vue";

import { useRouter } from "vue-router";

import MainLayout from "@/components/MainLayout.vue";
import UploadForm from "@/components/post/UploadForm.vue";

import { useMainStore } from "@/stores/main";

import type { PostInfo } from "@/models/api/post";

const mainStore = useMainStore();

const router = useRouter();

const uploading = ref(false);

const upload = async (info: PostInfo, file: File) => {
  uploading.value = true;

  const new_post = await mainStore.uploadPost(info, file);

  if (new_post) {
    mainStore.clearSearch();
    router.push({ name: "browse" });
  }
};
</script>

<template>
  <main :class="`theme-${mainStore.settings.theme}`">
    <MainLayout>
      <div class="content">
        <div class="title">Upload</div>
        <UploadForm :disabled="uploading" @upload="upload" />
      </div>
    </MainLayout>
  </main>
</template>

<style scoped lang="scss">
main {
  padding: 2rem;
}

.content {
  display: flex;
  flex-direction: column;
  gap: 1rem;
}

.title {
  font-size: 2rem;
}
</style>
