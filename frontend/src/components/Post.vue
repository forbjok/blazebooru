<script setup lang="ts">
import { computed, ref, toRefs } from "vue";

import Tags from "@/components/Tags.vue";
import TagsEditor from "./TagsEditor.vue";

import type { Post, PostInfo, UpdatePost } from "@/models/api/post";

import { make_image_path } from "@/utils/path";

interface Props {
  post: Post;
  can_edit?: boolean;
}

const props = withDefaults(defineProps<Props>(), {
  can_edit: false,
});

const emit = defineEmits<{
  (e: "update", request: UpdatePost): void;
}>();

const { post } = toRefs(props);

const editing = ref<PostInfo>();
const expand_image = ref(false);

const url = computed(() => make_image_path(post.value));

const beginEdit = () => {
  editing.value = {
    title: post.value.title,
    description: post.value.description,
    source: post.value.source,

    tags: [...post.value.tags],
  };
};

const cancelEdit = () => {
  editing.value = undefined;
};

const update = () => {
  const _editing = editing.value;
  if (!_editing) {
    return;
  }

  const add_tags = _editing.tags.filter((t) => !post.value.tags.includes(t));
  const remove_tags = post.value.tags.filter((t) => !_editing.tags.includes(t));

  const update_post: UpdatePost = {
    title: _editing.title,
    description: _editing.description,
    source: _editing.source,

    add_tags,
    remove_tags,
  };

  emit("update", update_post);

  editing.value = undefined;
};
</script>

<template>
  <div class="post">
    <div class="image" :class="{ expand: expand_image }" @click.prevent="expand_image = !expand_image">
      <a :href="url">
        <img :src="url" alt="Image" />
      </a>
    </div>
    <div class="actions">
      <a :href="url" :download="post.filename"><i class="fa-solid fa-download"></i> Download</a>
      <button v-if="can_edit" class="edit-button link-button" @click="beginEdit">
        <i class="fa-solid fa-pen-to-square"></i> Edit
      </button>
    </div>
    <div v-if="!editing" class="post-info">
      <div v-if="post.title" class="title">
        {{ post.title }}
      </div>
      <div class="user">Uploaded by: {{ post.user_name }}</div>
      <div v-if="post.source" class="source">Source: {{ post.source }}</div>
      <div v-if="post.tags">Tags: <Tags :tags="post.tags" /></div>
      <div v-if="post.description" class="description">
        <div class="header">Description</div>
        <div class="text">{{ post.description }}</div>
      </div>
    </div>
    <form v-if="editing" class="edit-form" @submit.prevent="update">
      <label>Title</label>
      <input name="title" type="text" v-model="editing.title" placeholder="Title" title="Title" />
      <label>Source</label>
      <input name="source" type="text" v-model="editing.source" placeholder="Source" title="Source" />

      <label>Tags</label>
      <TagsEditor v-model="editing.tags" />

      <label>Description</label>
      <textarea
        class="description-field"
        name="description"
        v-model="editing.description"
        placeholder="Description"
        wrap="soft"
      ></textarea>

      <div class="form-buttons">
        <input class="cancel-button" type="button" value="Cancel" @click="cancelEdit" />
        <input class="save-button" type="submit" value="Save" />
      </div>
    </form>
  </div>
</template>

<style scoped lang="scss">
.post {
  display: flex;
  flex-direction: column;
  align-items: start;
  gap: 0.5rem;
}

.actions {
  display: flex;
  flex-direction: row;
  gap: 1rem;
}

.post-info {
  display: flex;
  flex-direction: column;
  align-items: start;
  gap: 0.5rem;
}

.title {
  font-size: 2rem;
}

.description {
  display: flex;
  flex-direction: column;

  background-color: var(--color-description-background);

  max-width: 100%;

  .header {
    background-color: var(--color-description-header-background);

    padding: 0.3rem;
  }

  .text {
    padding: 0.4rem;
  }
}

.image {
  a {
    display: block;
  }

  img {
    background-color: var(--color-post-background);

    padding: 0.2rem;
  }

  &:not(.expand) img {
    max-width: 90vw;
    max-height: 90vh;
  }
}

// --- Edit form ---
.edit-form {
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

.form-buttons {
  display: flex;
  flex-direction: row;
  gap: 1rem;
}

.submit-button {
  margin-top: 1rem;
}
</style>
