<script setup lang="ts">
import { computed, onMounted, ref } from "vue";
import { useRouter } from "vue-router";

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
const editingTag = ref<Tag & { alias_of_tags: string[] }>();

const can_edit = computed(() => authStore.isAdmin);

onMounted(async () => {
  if (!authStore.isAuthorized) {
    router.replace({ name: "login" });
    return;
  }

  if (!authStore.isAdmin) {
    router.replace({ name: "browse" });
    return;
  }

  await tagsStore.initialize();
});

const beginEdit = (tag: Tag) => {
  originalTag.value = tag;
  editingTag.value = {
    ...tag,
    alias_of_tags: tag.alias_of_tag ? [tag.alias_of_tag] : [],
    implied_tags: [...tag.implied_tags],
  };

  editDialog.value?.show();
};

const cancelEdit = () => {
  editingTag.value = undefined;
  editDialog.value?.close();
};

const enterAliasOfTag = (tags: string[]) => {
  editingTag.value!.alias_of_tags = [tags[0]];
};

const deleteAliasOfTag = () => {
  editingTag.value!.alias_of_tags = [];
};

const saveEdit = async () => {
  const _editingTag = editingTag.value;
  if (!_editingTag) {
    return;
  }

  // Submit tag inputs
  tagEntry.value?.submit();
  tagsEditor.value?.submit();

  const add_implied_tags = _editingTag.implied_tags.filter((t) => !originalTag.value?.implied_tags.includes(t));
  const remove_implied_tags = originalTag.value?.implied_tags.filter((t) => !_editingTag.implied_tags.includes(t));

  const update_tag = {
    alias_of_tag: _editingTag.alias_of_tags[0],
    add_implied_tags,
    remove_implied_tags,
  };

  await tagsStore.updateTag(_editingTag.id, update_tag);
  await tagsStore.getTag(_editingTag.id);

  cancelEdit();
};
</script>

<template>
  <main :class="`theme-${mainStore.settings.theme}`">
    <MainLayout>
      <!-- Desktop -->
      <div class="layout">
        <table class="tags-table">
          <thead>
            <th>Tag</th>
            <th>Alias of</th>
            <th>Implied tags</th>
            <th v-if="can_edit">Actions</th>
          </thead>
          <tbody>
            <tr v-for="t of tagsStore.currentTags" :key="t.id" class="tag">
              <td>{{ t.tag }}</td>
              <td>{{ t.alias_of_tag }}</td>
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
          <label>Alias of</label>
          <div v-if="editingTag.alias_of_tags.length === 0">None</div>
          <Tags
            v-if="editingTag.alias_of_tags.length > 0"
            :tags="editingTag.alias_of_tags"
            :actions="true"
            @delete="deleteAliasOfTag"
          />
          <TagEntry ref="tagEntry" @enter="enterAliasOfTag" />

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
  background-color: var(--color-default-background);
  //border: 1px solid;
  border-spacing: 0;

  padding-top: 1rem;
  padding-bottom: 1rem;

  th {
    padding-right: 0.8rem;
    padding-bottom: 0.4rem;

    text-align: left;
  }

  th:first-child {
    padding-left: 1rem;
  }

  th:last-child {
    padding-right: 1rem;
  }

  tr {
    background-color: var(--color-default-background);
  }

  tr:nth-child(odd) {
    filter: brightness(0.9);
  }

  td {
    padding: 0.1rem 0.4rem;

    height: 1.6rem;
  }

  td:first-child {
    padding-left: 1rem;
  }

  td:not(:first-child) {
    border-left: 0.2rem solid var(--color-table-divider);
  }

  td:last-child {
    padding-right: 1rem;
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
