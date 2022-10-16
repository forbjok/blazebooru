<script setup lang="ts">
import { RouterView } from "vue-router";
</script>

<template>
  <RouterView />
</template>

<style scoped lang="scss">
@media only screen and (max-width: 480px) {
  main {
    max-width: 100vw;
  }
}
</style>
