<script setup lang="ts">
import { onMounted, ref } from "vue";
import { useRouter } from "vue-router";

import MainLayout from "@/components/MainLayout.vue";
import UploadForm from "@/components/upload/UploadForm.vue";

import { useAuthStore } from "@/stores/auth";
import { useMainStore } from "@/stores/main";
import { useUploadStore, type UploadPost } from "@/stores/upload";

const router = useRouter();

const authStore = useAuthStore();
const mainStore = useMainStore();
const uploadStore = useUploadStore();

const dropZoneRef = ref<HTMLElement>();

onMounted(async () => {
  if (!authStore.isAuthorized) {
    router.replace({ name: "login" });
    return;
  }
});

const upload = async (posts: UploadPost[]) => {
  posts.forEach((p) => uploadStore.queue(p));
  await uploadStore.processUploadQueue();
  await mainStore.refresh();
};
</script>

<template>
  <main :class="`theme-${mainStore.settings.theme}`">
    <MainLayout>
      <div ref="dropZoneRef" class="content">
        <div class="title">Upload</div>
        <UploadForm :dropZoneRef="dropZoneRef" @upload="upload" />
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
  align-items: center;
  gap: 1rem;

  height: 100%;
}

.title {
  font-size: 2rem;
}
</style>
