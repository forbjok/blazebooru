<script setup lang="ts">
import { computed, onMounted, ref } from "vue";
import { useRouter } from "vue-router";
import { onKeyDown } from "@vueuse/core";

import Button from "@/components/common/Button.vue";
import Dialog from "@/components/common/Dialog.vue";
import Toolbar from "@/components/common/Toolbar.vue";
import MainLayout from "@/components/MainLayout.vue";
import TagEntry from "../components/tag/TagEntry.vue";
import Tags from "../components/tag/Tags.vue";
import TagsEditor from "../components/tag/TagsEditor.vue";

import { useAuthStore } from "@/stores/auth";
import { useMainStore } from "@/stores/main";
import { useTagsStore } from "@/stores/tags";

import type { Tag } from "@/models/api/tag";

const router = useRouter();

const authStore = useAuthStore();
const mainStore = useMainStore();
const tagsStore = useTagsStore();

const editDialog = ref<typeof Dialog>();
const tagEntry = ref<typeof TagEntry>();
const tagsEditor = ref<typeof TagsEditor>();

const originalTag = ref<Tag>();
const editingTag = ref<Tag>();

const tags = computed(() => tagsStore.currentTags.filter((t) => !t.alias_of_tag));

const can_edit = computed(() => authStore.isAdmin);

onMounted(async () => {
  // Ensure the auth store has fully initialized
  // in order to be able to know whether the user is an admin.
  await authStore.isInitialized();

  if (!authStore.isAuthorized) {
    router.replace({ name: "login" });
    return;
  }

  if (!authStore.isAdmin) {
    router.replace({ name: "browse" });
    return;
  }

  await tagsStore.refresh();
});

// Override F5 to refresh the results
// without performing a full browser refresh.
onKeyDown("F5", async (e) => {
  if (e.ctrlKey) {
    return;
  }

  e.preventDefault();
  await tagsStore.refresh();
});

const beginEdit = (tag: Tag) => {
  originalTag.value = tag;
  editingTag.value = {
    ...tag,
    aliases: [...tag.aliases],
    implied_tags: [...tag.implied_tags],
  };

  editDialog.value?.show();
};

const cancelEdit = () => {
  editingTag.value = undefined;
  editDialog.value?.close();
};

const getTagByName = (tag: string): Tag | undefined => {
  return tagsStore.currentTags.find((t) => t.tag === tag);
};

const saveEdit = async () => {
  const _editingTag = editingTag.value;
  const _originalTag = originalTag.value;
  if (!_editingTag || !_originalTag) {
    return;
  }

  // Submit tag inputs
  tagEntry.value?.submit();
  tagsEditor.value?.submit();

  const add_aliases = _editingTag.aliases.filter((t) => !_originalTag.aliases.includes(t));
  const remove_aliases = _originalTag.aliases.filter((t) => !_editingTag.aliases.includes(t));
  const add_implied_tags = _editingTag.implied_tags.filter((t) => !_originalTag.implied_tags.includes(t));
  const remove_implied_tags = _originalTag.implied_tags.filter((t) => !_editingTag.implied_tags.includes(t));

  const update_tag = {
    add_aliases,
    remove_aliases,
    add_implied_tags,
    remove_implied_tags,
  };

  await tagsStore.updateTag(_editingTag.id, update_tag);
  await tagsStore.getTag(_editingTag.id);

  for (const alt of [...add_aliases, ...remove_aliases]) {
    const altId = getTagByName(alt)?.id;
    if (!altId) {
      continue;
    }

    await tagsStore.getTag(altId);
  }

  cancelEdit();
};

const clickTag = async (tag: string) => {
  await mainStore.searchPosts({ tags: [tag], exclude_tags: [] });
  router.push({ name: "browse" });
};
</script>

<template>
  <main>
    <MainLayout>
      <!-- Desktop -->
      <div class="layout">
        <table class="tags-table">
          <thead>
            <th>Tag</th>
            <th>Aliases</th>
            <th>Implied tags</th>
            <th v-if="can_edit">Actions</th>
          </thead>
          <tbody>
            <tr v-for="t of tags" :key="t.id" class="tag">
              <td>
                <button class="link-button" type="button" @click="clickTag(t.tag)">{{ t.tag }}</button>
              </td>
              <td>
                <Tags :tags="t.aliases" />
              </td>
              <td>
                <Tags :tags="t.implied_tags" />
              </td>
              <td v-if="can_edit">
                <button v-if="can_edit" class="edit-tag-button link-button" @click="beginEdit(t)">
                  <i class="fa-solid fa-pen-to-square"></i> Edit
                </button>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </MainLayout>

    <Dialog ref="editDialog" :darken="true" :title="`Edit tag [ ${editingTag?.tag} ]`" @closed="cancelEdit">
      <div class="edit-dialog">
        <div v-if="editingTag" class="content">
          <label>Aliases</label>
          <TagsEditor v-model="editingTag.aliases" />

          <label>Implied tags</label>
          <TagsEditor ref="tagsEditor" v-model="editingTag.implied_tags" />
        </div>
        <Toolbar class="choices">
          <Button @click="saveEdit">
            <slot name="save"><i class="fa-solid fa-check"></i> Save</slot>
          </Button>
          <Button @click="cancelEdit"><i class="fa-solid fa-ban"></i> Cancel</Button>
        </Toolbar>
      </div>
    </Dialog>
  </main>
</template>

<style scoped lang="scss">
main {
  padding: 1rem;
}

.tags-table {
  border-spacing: 0;

  padding-top: 1rem;
  padding-bottom: 1rem;

  th {
    background-color: var(--color-list-header-background);

    padding: 0.4rem;

    text-align: left;
  }

  tr {
    background-color: var(--color-list-background);

    &:nth-child(even) {
      background-color: var(--color-list-alt-background);
    }
  }

  td {
    padding: 0.1rem 0.4rem;

    height: 1.6rem;
  }

  td:not(:first-child) {
    border-left: 0.2rem solid var(--color-table-divider);
  }
}

.edit-dialog {
  display: flex;
  flex-direction: column;

  width: 100%;
  height: 100%;

  overflow: hidden;

  .content {
    flex-grow: 1;

    display: flex;
    flex-direction: column;
    gap: 0.4rem;

    padding: 1rem;
  }

  .choices {
    flex-shrink: 0;
    flex-direction: row-reverse;
  }
}
</style>
