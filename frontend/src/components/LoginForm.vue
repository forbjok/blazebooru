<script setup lang="ts">
import type { LoginRequest } from "@/models/api/login";
import { reactive } from "vue";

const emit = defineEmits<{
  (e: "log-in", request: LoginRequest): void;
}>();

const vm = reactive<LoginRequest>({
  name: "",
  password: "",
});
</script>

<template>
  <form class="login-form" @submit.prevent="emit('log-in', vm)">
    <label>Username</label>
    <input name="user_name" type="text" v-model="vm.name" pattern="^[\d\w_]+$" placeholder="Username" required />
    <label>Password</label>
    <input name="password" type="password" v-model="vm.password" placeholder="Password" required />

    <input class="submit-button" type="submit" value="Log in" />
  </form>
</template>

<style scoped lang="scss">
.login-form {
  display: flex;
  flex-direction: column;
  align-items: start;
  gap: 0.5rem;
}

.submit-button {
  margin-top: 1rem;
}
</style>
