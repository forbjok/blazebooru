<script setup lang="ts">
import { useUploadStore } from "@/stores/upload";

const uploadStore = useUploadStore();
</script>

<template>
  <div class="upload-progress">
    <table class="queue-table">
      <thead>
        <tr>
          <th>Filename</th>
          <th>Status</th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="qp in uploadStore.queuedPosts">
          <td>
            <router-link
              v-if="qp.post_id"
              :to="{ name: 'post', params: { id: qp.post_id } }"
              class="post"
            >
              {{ qp.file.name }}
            </router-link>
            <span v-else>{{ qp.file.name }}</span>
          </td>
          <td>
            <span v-if="qp.is_uploading">{{ qp.progress }}%</span>
            <span v-else-if="!!qp.post_id"
              ><i class="fa-solid fa-check"></i
            ></span>
            <span v-else-if="qp.error_message" :title="qp.error_message"
              ><i class="fa-solid fa-triangle-exclamation"></i
            ></span>
          </td>
        </tr>
      </tbody>
    </table>
  </div>
</template>

<style scoped lang="scss">
.queue-table {
  border-collapse: collapse;

  th {
    background-color: var(--color-list-header-background);
    padding: 0.2rem;
    padding-right: 0.4rem;
    text-align: left;
  }

  tr {
    background-color: var(--color-list-background);

    &:nth-child(odd) {
      background-color: var(--color-list-alt-background);
    }
  }

  td {
    padding: 0.2rem;
  }
}
</style>
