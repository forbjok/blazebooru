<script setup lang="ts">
import { useUploadStore } from "@/stores/upload";

const uploadStore = useUploadStore();
</script>

<template>
  <div class="upload-progress">
    <table class="queue-table">
      <tr>
        <th>Filename</th>
        <th>Status</th>
      </tr>
      <tr v-for="qp in uploadStore.queuedPosts">
        <td>
          {{ qp.file.name }}
        </td>
        <td>
          <span v-if="qp.is_uploading">{{ qp.progress }}%</span>
          <span v-if="!!qp.post_id"><i class="fa-solid fa-check"></i></span>
        </td>
      </tr>
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
