<script setup lang="ts">
import MainLayout from "@/components/MainLayout.vue";
import MultiUploadForm from "@/components/upload/MultiUploadForm.vue";

import { useMainStore } from "@/stores/main";
import { useUploadStore, type UploadPost } from "@/stores/upload";

const mainStore = useMainStore();
const uploadStore = useUploadStore();

const upload = async (posts: UploadPost[]) => {
  posts.forEach((p) => uploadStore.queue(p));
  await uploadStore.processUploadQueue();
  await mainStore.refresh();
};
</script>

<template>
  <main :class="`theme-${mainStore.settings.theme}`">
    <MainLayout>
      <div class="content">
        <div class="title">Upload</div>
        <MultiUploadForm @upload="upload" />
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
