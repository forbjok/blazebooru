<script setup lang="ts">
import type { LoginRequest } from "@/models/api/login";
import { reactive, ref } from "vue";

const emit = defineEmits<{
  (e: "register", request: LoginRequest): void;
}>();

const usernameInput = ref<HTMLInputElement>();

const vm = reactive<LoginRequest>({
  name: "",
  password: "",
});

const focus = () => {
  usernameInput.value?.focus();
};

defineExpose({
  focus,
});
</script>

<template>
  <form class="register-form" @submit.prevent="emit('register', vm)">
    <label>Username</label>
    <input
      ref="usernameInput"
      v-model="vm.name"
      name="user_name"
      type="text"
      pattern="^[\d\w_]+$"
      placeholder="Username"
      title="Only alphanumeric characters and underscore allowed."
      required
    />

    <label>Password</label>
    <input v-model="vm.password" name="password" type="password" placeholder="Password" required />

    <input class="submit-button" type="submit" value="Register" />
  </form>
</template>

<style scoped lang="scss">
.register-form {
  display: flex;
  flex-direction: column;
  align-items: start;
  gap: 0.5rem;
}

.submit-button {
  margin-top: 1rem;
}
</style>
