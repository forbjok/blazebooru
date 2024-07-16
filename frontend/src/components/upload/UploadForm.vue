<script setup lang="ts">
import { computed, onMounted, reactive, ref, toRefs } from "vue";
import { filesize } from "filesize";

import TagsEditor from "@/components/tag/TagsEditor.vue";

import type { PostInfo } from "@/models/api/post";

import { useMainStore } from "@/stores/main";
import type { UploadPost } from "@/stores/upload";

import type { SysConfig } from "@/models/api/sys";

const mainStore = useMainStore();

interface PostViewModel {
  title: string;
  description: string;
  source: string;
  tags: string[];
  file: File;
  previewUrl: string;
  progress: number;
}

interface ViewModel {
  tags: string[];
  posts: PostViewModel[];
}

const emit = defineEmits<{
  (e: "upload", posts: UploadPost[]): void;
}>();

const tagsEditor = ref<typeof TagsEditor>();

const vm = reactive<ViewModel>({
  tags: [],
  posts: [],
});

const sysConfig = ref<SysConfig>();

const maxImageSizeText = computed(() => filesize(sysConfig.value?.max_image_size || 0));

onMounted(async () => {
  sysConfig.value = await mainStore.getSysConfig();
});

const fileSelected = (event: Event) => {
  const input = event.target as HTMLInputElement;
  if (!input || !input.files) return;

  const maxImageSize = sysConfig.value?.max_image_size || 0;

  for (const file of input.files) {
    if (file && file.size > maxImageSize) {
      alert(
        `The selected file '${file.name}' is bigger than the maximum allowed size of ${filesize(maxImageSize)} and will be ignored.`,
      );
      continue;
    }

    const new_post: PostViewModel = {
      title: "",
      description: "",
      source: "",
      tags: [],
      file,
      previewUrl: URL.createObjectURL(file),
      progress: 0,
    };

    vm.posts.push(new_post);
  }

  input.value = "";
};

const canSubmit = computed(() => {
  return vm.posts.length > 0;
});

const upload = () => {
  const uploadPosts: UploadPost[] = [];

  for (const p of vm.posts) {
    let info: PostInfo = {
      title: p.title,
      description: p.description,
      source: p.source,
      tags: [...vm.tags, ...p.tags],
    };

    uploadPosts.push({ info, file: p.file });
  }

  emit("upload", uploadPosts);

  vm.posts = [];
};
</script>

<template>
  <form class="upload-form" @submit.prevent="upload">
    <label>Common tags</label>
    <TagsEditor ref="tagsEditor" v-model="vm.tags" />

    <input name="file" type="file" accept="image/*" @change="fileSelected" multiple="true" />
    <p>Max file size: {{ maxImageSizeText }}</p>

    <table class="posts-table">
      <tr>
        <th>Preview</th>
        <th>Info</th>
      </tr>
      <tr v-for="p in vm.posts">
        <td>
          <div class="image-preview"><img :src="p.previewUrl" :alt="p.file.name" /></div>
        </td>
        <td>
          <div class="post-info">
            <label>Filename: {{ p.file.name }}</label>

            <label class="post-title">Title</label>
            <input name="title" type="text" v-model="p.title" placeholder="Title" title="Title" />

            <label>Description</label>
            <textarea
              class="description-field"
              name="description"
              v-model="p.description"
              placeholder="Description"
              wrap="soft"
            ></textarea>

            <label>Source</label>
            <input name="source" type="text" v-model="p.source" placeholder="Source" title="Source" />

            <label>Tags</label>
            <TagsEditor v-model="p.tags" />
          </div>
        </td>
      </tr>
    </table>

    <input :disabled="!canSubmit" class="submit-button" type="submit" value="Upload" />
  </form>
</template>

<style scoped lang="scss">
.upload-form {
  display: flex;
  flex-direction: column;
  align-items: start;
  gap: 0.5rem;
}

.description-field {
  resize: both;

  width: 30rem;
  height: 4rem;

  max-width: 100%;
}

.submit-button {
  margin-top: 1rem;
}

.image-preview {
  display: flex;
  flex-direction: column;

  max-width: 16rem;

  img {
    background-color: var(--color-post-background);
    margin-top: 0.1rem;
  }
}

.posts-table {
  border-collapse: collapse;

  th {
    background-color: var(--color-list-header-background);
    padding: 0.2rem;
  }

  tr {
    background-color: var(--color-list-background);

    &:nth-child(odd) {
      background-color: var(--color-list-alt-background);
    }
  }

  td {
    overflow: hidden;
    vertical-align: top;
  }
}

.post-info {
  display: flex;
  flex-direction: column;
  padding: 0.4rem;

  .post-title {
    margin-top: 0.4rem;
  }
}
</style>
