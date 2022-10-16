<script setup lang="ts"></script>

<template>
  <button>
    <slot></slot>
  </button>
</template>

<style scoped lang="scss">
button {
  background: none;
  border: none;
  color: var(--color-link);

  padding: 5px;

  &:enabled {
    cursor: pointer !important;
  }

  &:hover {
    background: none;
    color: var(--color-link-hover);

    cursor: pointer;
  }
}
</style>
