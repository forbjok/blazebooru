<script setup lang="ts">
import MainLayout from "@/components/MainLayout.vue";
import UploadProgress from "@/components/upload/UploadProgress.vue";
</script>

<template>
  <main>
    <MainLayout>
      <div class="content">
        <div class="title">Upload progress</div>
        <UploadProgress />
      </div>
    </MainLayout>
  </main>
</template>

<style scoped lang="scss">
main {
  padding: 2rem;
}

.content {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 1rem;
}

.title {
  font-size: 2rem;
}
</style>
