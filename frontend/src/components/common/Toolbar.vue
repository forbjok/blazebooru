<script setup lang="ts"></script>

<template>
  <div class="toolbar">
    <slot></slot>
  </div>
</template>

<style scoped lang="scss">
.toolbar {
  flex-shrink: 0;

  display: flex;
  flex-direction: row;
  gap: 0.2rem;

  width: 100%;

  padding: 0.1rem;
}
</style>
