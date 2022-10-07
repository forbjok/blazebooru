<script setup lang="ts">
import { computed, reactive, toRefs } from "vue";

import { filesize } from "filesize";

import type { PostInfo } from "@/models/api/post";

interface Props {
  disabled?: boolean;
}

interface ViewModel {
  title: string;
  description: string;
  file?: File;
}

const MAX_IMAGE_SIZE = 10_000_000;

const props = withDefaults(defineProps<Props>(), {
  disabled: false,
});

const emit = defineEmits<{
  (e: "upload", info: PostInfo, file: File): void;
}>();

const { disabled } = toRefs(props);

const vm = reactive<ViewModel>({
  title: "",
  description: "",
});

const previewImage = computed(() => {
  if (!vm.file) {
    return;
  }

  return URL.createObjectURL(vm.file);
});

const fileSelected = (event: Event) => {
  const input = event.target as HTMLInputElement;
  if (!input || !input.files) return;

  const file = input.files[0];

  if (file && file.size > MAX_IMAGE_SIZE) {
    alert(`The selected file is bigger than the maximum allowed size of ${filesize(MAX_IMAGE_SIZE)}`);
    return;
  }

  vm.file = file;
};

const canSubmit = computed(() => {
  if (disabled.value) {
    return false;
  }

  return !!vm.file;
});

const upload = () => {
  if (!vm.file) {
    return;
  }

  let info: PostInfo = {};

  if (vm.title) {
    info.title = vm.title;
  }

  if (vm.description) {
    info.description = vm.description;
  }

  emit("upload", info, vm.file);
};
</script>

<template>
  <form class="upload-form" @submit.prevent="upload">
    <label>Title</label>
    <input name="title" type="text" v-model="vm.title" placeholder="Title" title="Title" :disabled="disabled" />

    <label>Description</label>
    <textarea
      :readonly="disabled"
      class="description-field"
      name="description"
      v-model="vm.description"
      placeholder="Description"
      wrap="soft"
    ></textarea>

    <input name="file" type="file" accept="image/*" @change="fileSelected" :disabled="disabled" />

    <input :disabled="!canSubmit" class="submit-button" type="submit" value="Upload" />
  </form>

  <div v-show="previewImage" class="image-preview">
    <label>Image preview:</label>
    <img :src="previewImage" alt="Preview" />
  </div>
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
  height: 10rem;

  max-width: 100%;
}

.submit-button {
  margin-top: 1rem;
}

.image-preview {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;

  margin-top: 3rem;

  max-width: 100%;

  img {
    background-color: var(--color-post-background);
    padding: 1rem;
  }
}
</style>
