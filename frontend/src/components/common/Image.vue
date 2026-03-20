<script setup lang="ts">
import { computed, toRefs } from "vue";

const VIDEO_EXTS = ["webm", "mp4", "m4v"];

const props = defineProps<{
  src: string;
  forceVideo?: boolean;
}>();

const { src, forceVideo } = toRefs(props);

const isVideo = computed(() => forceVideo.value || VIDEO_EXTS.includes(src.value?.split(".").pop()));
</script>

<template>
  <div class="image">
    <img v-if="!isVideo" :src="src" />
    <video v-if="isVideo" :src="src" autoplay loop muted></video>
  </div>
</template>

<style scoped lang="scss">
.image {
  display: block;

  max-width: inherit;
  max-height: inherit;

  img,
  video {
    display: block;

    max-width: inherit;
    max-height: inherit;
  }
}
</style>
