<script setup lang="ts">
import { ref, toRefs } from "vue";

import ConfirmDialog from "@/components/common/ConfirmDialog.vue";
import Tags from "@/components/tag/Tags.vue";
import TagsEditor from "@/components/tag/TagsEditor.vue";

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
  (e: "delete"): void;
  (e: "update", request: UpdatePost): void;
}>();

const { post } = toRefs(props);

const confirmDelete = ref<typeof ConfirmDialog>();
const tagsEditor = ref<typeof TagsEditor>();

const editing = ref<PostInfo>();

const toggleEdit = () => {
  if (!editing.value) {
    editing.value = {
      title: post.value.title,
      description: post.value.description,
      source: post.value.source,

      tags: [...post.value.tags],
    };
  } else {
    cancelEdit();
  }
};

const cancelEdit = () => {
  editing.value = undefined;
};

const update = () => {
  const _editing = editing.value;
  if (!_editing) {
    return;
  }

  // Force submit the tag entry
  tagsEditor.value?.submit();

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

const deletePost = () => {
  emit("delete");
};
</script>

<template>
  <div class="post-info">
    <div class="header">
      <div class="uploader" title="Uploader"><i class="fa-solid fa-user"></i> {{ post.user_name }}</div>
      <div class="actions">
        <a :href="make_image_path(post)" :download="post.filename"><i class="fa-solid fa-download"></i> Download</a>
        <button v-if="can_edit" class="delete-button link-button" @click="confirmDelete?.show()">
          <i class="fa-solid fa-trash"></i> Delete
        </button>
        <button v-if="can_edit" class="edit-button link-button" @click="toggleEdit">
          <i class="fa-solid fa-pen-to-square"></i> Edit
        </button>
      </div>
    </div>
    <hr />
    <div v-if="!editing" class="post-info">
      <div v-if="post.title" class="title" :title="post.title">
        {{ post.title }}
      </div>
      <div v-if="post.source" class="source">Source: {{ post.source }}</div>
      <div v-if="post.tags" class="tags">
        Tags:
        <Tags :tags="post.tags" />
      </div>
      <hr />
      <div v-if="post.description" class="description">
        {{ post.description }}
      </div>
      <hr />
    </div>
    <form v-if="editing" class="edit-form" @submit.prevent="update">
      <label>Title</label>
      <input name="title" type="text" v-model="editing.title" placeholder="Title" title="Title" />
      <label>Source</label>
      <input name="source" type="text" v-model="editing.source" placeholder="Source" title="Source" />

      <label>Tags</label>
      <TagsEditor ref="tagsEditor" v-model="editing.tags" />

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

    <ConfirmDialog ref="confirmDelete" title="Confirm delete" @confirm="deletePost">
      <template v-slot:confirm><i class="fa-solid fa-trash"></i> Delete</template>
      <div class="confirm-delete-dialog">Are you sure you want to delete this post?</div>
    </ConfirmDialog>
  </div>
</template>

<style scoped lang="scss">
.post-info {
  display: flex;
  flex-direction: column;
  gap: 0.4rem;
}

.header {
  display: flex;
  flex-direction: row;
  gap: 1rem;

  width: 100%;

  cursor: default;

  .uploader {
    flex-shrink: 1;
  }

  .actions {
    flex-grow: 1;

    display: flex;
    flex-direction: row;
    justify-content: end;
    gap: 1rem;
  }
}

.title {
  font-size: 2rem;

  text-overflow: ellipsis;
  white-space: nowrap;
  overflow: hidden;
}

.tags {
  overflow: hidden;
}

.description {
  margin: 0.5rem 0;
}

// --- Edit form ---
.edit-form {
  display: flex;
  flex-direction: column;
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
  align-self: end;
  gap: 1rem;
}

.submit-button {
  margin-top: 1rem;
}
</style>
