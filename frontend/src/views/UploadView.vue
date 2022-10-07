<script setup lang="ts">
import { inject, onMounted, ref } from "vue";

import { useRouter } from "vue-router";

import MainLayout from "@/components/MainLayout.vue";
import UploadForm from "@/components/UploadForm.vue";

import type { Settings } from "@/models/settings";
import type { BlazeBooruApiService } from "@/services/api";
import type { PostInfo } from "@/models/api/post";
import type { BlazeBooruAuthService } from "@/services/auth";

const router = useRouter();

const api = inject<BlazeBooruApiService>("api")!;
const auth = inject<BlazeBooruAuthService>("auth")!;
const settings = inject<Settings>("settings")!;

const uploading = ref(false);

onMounted(async () => {
  await auth.setup();
});

const upload = async (info: PostInfo, file: File) => {
  uploading.value = true;

  const new_post = await api.upload_post(info, file);

  if (new_post) {
    router.push({ name: "posts" });
  }
};
</script>

<template>
  <main :class="`theme-${settings.theme}`">
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
