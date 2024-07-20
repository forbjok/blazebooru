<script setup lang="ts">
import { computed, reactive, ref, toRefs, watch } from "vue";
import { filesize } from "filesize";

import TagsEditor from "@/components/tag/TagsEditor.vue";

import { useMainStore } from "@/stores/main";
import type { StagedPost } from "@/stores/upload";

import { useDropZone } from "@vueuse/core";

const mainStore = useMainStore();

interface ViewModel {
  commonTags: string[];
  posts: StagedPost[];
}

const props = defineProps<{
  commonTags: string[];
  posts: StagedPost[];
  dropZoneRef?: HTMLElement;
}>();

const emit = defineEmits<{
  (e: "add", post: StagedPost): void;
  (e: "remove", post: StagedPost): void;
  (e: "upload", posts: StagedPost[]): void;
}>();

const { commonTags, posts, dropZoneRef } = toRefs(props);

const fileInput = ref<typeof HTMLInputElement>();
const tagsEditor = ref<typeof TagsEditor>();

const vm = reactive<ViewModel>({
  commonTags: commonTags.value || [],
  posts: posts.value || [],
});

const maxImageSize = computed(() => mainStore.sysConfig?.max_image_size || 0);
const maxImageSizeText = computed(() => filesize(maxImageSize.value));

watch(commonTags, (v) => {
  vm.commonTags = v;
});

watch(posts, (v) => {
  vm.posts = v;
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

  const new_post: StagedPost = {
    title: "",
    description: "",
    source: "",
    tags: [],
    file,
    previewUrl: URL.createObjectURL(file),
  };

  emit("add", new_post);
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

const removePost = (post: StagedPost) => {
  emit("remove", post);
};

const upload = () => {
  emit("upload", vm.posts);
};
</script>

<template>
  <form class="upload-form" @submit.prevent="upload">
    <div class="common-tags">
      <label>Common tags</label>
      <TagsEditor ref="tagsEditor" v-model="vm.commonTags" />
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

    <button type="button" class="add-files-button" @click="addFiles">
      <i class="fa-solid fa-plus"></i>
      <span>Add files</span>
    </button>

    <p>Max file size: {{ maxImageSizeText }}</p>

    <br />

    <table class="posts-table">
      <thead>
        <tr>
          <th>Preview</th>
          <th>Info</th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="p in vm.posts">
          <td class="image-preview">
            <div class="image-preview"><img :src="p.previewUrl" :alt="p.file.name" /></div>
          </td>
          <td>
            <div class="post-info">
              <div class="post-filename">
                <div class="filename">Filename: {{ p.file.name }}</div>
                <button type="button" @click="removePost(p)" alt="Remove">
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
      </tbody>
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

    &:nth-child(even) {
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
