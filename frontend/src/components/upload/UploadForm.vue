<script setup lang="ts">
import { computed, onMounted, reactive, ref, toRefs } from "vue";
import { filesize } from "filesize";

import TagsEditor from "@/components/tag/TagsEditor.vue";

import type { PostInfo } from "@/models/api/post";

import { useMainStore } from "@/stores/main";
import type { UploadPost } from "@/stores/upload";

import type { SysConfig } from "@/models/api/sys";
import { useDropZone } from "@vueuse/core";

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

const props = defineProps<{
  dropZoneRef?: HTMLElement;
}>();

const emit = defineEmits<{
  (e: "upload", posts: UploadPost[]): void;
}>();

const { dropZoneRef } = toRefs(props);

const fileInput = ref<typeof HTMLInputElement>();
const tagsEditor = ref<typeof TagsEditor>();

const vm = reactive<ViewModel>({
  tags: [],
  posts: [],
});

const sysConfig = ref<SysConfig>();

const maxImageSize = computed(() => sysConfig.value?.max_image_size || 0);
const maxImageSizeText = computed(() => filesize(maxImageSize.value));

onMounted(async () => {
  sysConfig.value = await mainStore.getSysConfig();
});

const addFile = (file: File) => {
  // If file is not an image, ignore it.
  if (!file.type.startsWith("image/")) {
    return;
  }

  if (file && file.size > maxImageSize.value) {
    alert(
      `The selected file '${file.name}' is bigger than the maximum allowed size of ${maxImageSizeText.value} and will be ignored.`,
    );

    return;
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
};

const filesSelected = (event: Event) => {
  const input = event.target as HTMLInputElement;
  if (!input || !input.files) return;

  for (const file of input.files) {
    addFile(file);
  }

  input.value = "";
};

const filesDropped = (files: File[] | null) => {
  if (!files) {
    return;
  }

  for (const file of files) {
    addFile(file);
  }
};

useDropZone(dropZoneRef, { onDrop: filesDropped });

const canSubmit = computed(() => {
  return vm.posts.length > 0;
});

const addFiles = () => {
  (fileInput.value as any)?.click();
};

const removePost = (post: PostViewModel) => {
  vm.posts = vm.posts.filter((p) => p !== post);
};

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
    <div class="common-tags">
      <label>Common tags</label>
      <TagsEditor ref="tagsEditor" v-model="vm.tags" />
    </div>

    <br />

    <input
      ref="fileInput"
      name="file"
      type="file"
      accept="image/*"
      @change="filesSelected"
      multiple="true"
      class="file-input"
    />

    <button @click.prevent="addFiles" class="add-files-button">
      <i class="fa-solid fa-plus"></i>
      <span>Add files</span>
    </button>

    <p>Max file size: {{ maxImageSizeText }}</p>

    <br />

    <table class="posts-table">
      <tr>
        <th>Preview</th>
        <th>Info</th>
      </tr>
      <tr v-for="p in vm.posts">
        <td class="image-preview">
          <div class="image-preview"><img :src="p.previewUrl" :alt="p.file.name" /></div>
        </td>
        <td>
          <div class="post-info">
            <div class="post-filename">
              <div class="filename">Filename: {{ p.file.name }}</div>
              <button @click.prevent="removePost(p)" alt="Remove">
                <i class="fa-solid fa-trash"></i>
              </button>
            </div>

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

    <br />

    <input :disabled="!canSubmit" class="submit-button" type="submit" value="Upload" />
  </form>
</template>

<style scoped lang="scss">
.upload-form {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.5rem;
}

.description-field {
  resize: both;

  width: 30rem;
  height: 4rem;

  max-width: 100%;
}

.file-input {
  display: none;
}

.add-files-button {
  display: flex;
  flex-direction: row;
  gap: 0.2rem;

  padding: 0.4rem 0.6rem;
  border-radius: 0.2rem;
}

.submit-button {
  padding: 0.4rem 0.6rem;
}

div.image-preview {
  display: flex;
  align-items: center;
  justify-content: center;

  width: 16vw;
  max-height: 16vw;

  img {
    display: block;

    margin-top: 0.1rem;

    max-width: 16vw;
    max-height: 16vw;
  }
}

.posts-table {
  border-collapse: collapse;

  min-width: 40vw;

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

    &.image-preview {
      background-color: black;
      vertical-align: middle;
    }
  }
}

.post-info {
  display: flex;
  flex-direction: column;
  padding: 0.4rem;

  .post-title {
    margin-top: 0.4rem;
  }

  .post-filename {
    display: flex;
    flex-direction: row;

    .filename {
      flex-grow: 1;
    }

    button {
      flex-shrink: 0;

      font-size: 1.1rem;

      border: none;
      color: var(--color-button-text);
      background-color: var(--color-button-background);

      padding: 0.2rem 0.4rem;

      &:enabled {
        cursor: pointer !important;
      }

      &:hover {
        color: var(--color-button-hover);
        cursor: pointer;
      }
    }
  }
}
</style>
