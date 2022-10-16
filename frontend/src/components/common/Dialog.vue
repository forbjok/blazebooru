<script lang="ts">
export default {
  inheritAttrs: false,
};
</script>

<script setup lang="ts">
import { ref, toRefs } from "vue";

import Modal from "./Modal.vue";
import Button from "./Button.vue";

const props = defineProps<{
  title: string;
  darken?: boolean;
}>();

const emit = defineEmits<{
  (e: "closed"): void;
}>();

const { title } = toRefs(props);

const isOpen = ref(false);

const show = () => {
  isOpen.value = true;
};

const close = () => {
  if (!isOpen.value) {
    return;
  }

  isOpen.value = false;
  emit("closed");
};

defineExpose({
  show,
  close,
});
</script>

<template>
  <Modal :show="isOpen" :darken="darken" v-bind="$attrs" @clickoutside="close">
    <div class="dialog">
      <div class="title">
        <span class="caption">{{ title }}</span
        ><Button class="close-button" @click="close"><i class="fa-solid fa-xmark"></i></Button>
      </div>
      <div class="content" v-bind="$attrs">
        <slot></slot>
      </div>
    </div>
  </Modal>
</template>

<style scoped lang="scss">
.dialog {
  background-color: var(--color-dialog-background);
  color: var(--color-default-text);
  border: 1px solid black;

  display: flex;
  flex-direction: column;

  width: 100%;
  height: 100%;

  max-width: 100vw;
  max-height: 100vh;

  overflow: hidden;

  .title {
    flex-shrink: 0;

    display: flex;
    flex-direction: row;

    background-color: var(--color-dialog-header-background);

    cursor: default;

    .caption {
      flex-grow: 1;

      padding: 0.25rem 0.3rem;
    }

    .close-button {
      flex-shrink: 0;

      font-size: 1.1rem;

      padding: 0 6px;
    }
  }

  .content {
    flex-grow: 1;
  }
}
</style>
