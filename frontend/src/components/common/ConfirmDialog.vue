<script setup lang="ts">
import { ref } from "vue";

import Button from "@/components/common/Button.vue";
import Dialog from "@/components/common/Dialog.vue";
import Toolbar from "@/components/common/Toolbar.vue";

const emit = defineEmits<{
  (e: "confirm"): void;
  (e: "cancel"): void;
}>();

const dialog = ref<typeof Dialog>();

let isConfirmed = false;

const confirm = () => {
  isConfirmed = true;
  emit("confirm");
  dialog.value?.close();
};

const cancel = () => {
  dialog.value?.close();
};

const dialogClosed = () => {
  if (!isConfirmed) {
    emit("cancel");
  }
};

const show = () => {
  isConfirmed = false;
  dialog.value?.show();
};

defineExpose({
  show,
});
</script>

<template>
  <Dialog ref="dialog" :darken="true" title="Confirm action" @closed="dialogClosed">
    <div class="confirm-dialog">
      <div class="content">
        <slot></slot>
      </div>
      <Toolbar class="choices">
        <Button @click="confirm"
          ><slot name="confirm"><i class="fa-solid fa-check"></i> Confirm</slot></Button
        >
        <Button @click="cancel"><i class="fa-solid fa-ban"></i> Cancel</Button>
      </Toolbar>
    </div>
  </Dialog>
</template>

<style scoped lang="scss">
.confirm-dialog {
  display: flex;
  flex-direction: column;

  width: 100%;
  height: 100%;

  overflow: hidden;

  .content {
    flex-grow: 1;

    padding: 10px;
  }

  .choices {
    flex-shrink: 0;
    flex-direction: row-reverse;
  }
}
</style>
