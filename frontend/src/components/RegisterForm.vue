<script setup lang="ts">
import type { LoginRequest } from "@/models/api/login";
import { reactive } from "vue";

const emit = defineEmits<{
  (e: "register", request: LoginRequest): void;
}>();

const vm = reactive<LoginRequest>({
  name: "",
  password: "",
});
</script>

<template>
  <form class="register-form" @submit.prevent="emit('register', vm)">
    <label>Username</label>
    <input name="user_name" type="text" v-model="vm.name" placeholder="Username" />
    <label>Password</label>
    <input name="password" type="password" v-model="vm.password" placeholder="Password" />

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
