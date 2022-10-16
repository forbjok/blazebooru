<script setup lang="ts">
import { useRouter } from "vue-router";

import MainLayout from "@/components/MainLayout.vue";
import RegisterForm from "@/components/RegisterForm.vue";

import { useAuthStore } from "@/stores/auth";
import { useMainStore } from "@/stores/main";

import type { LoginRequest } from "@/models/api/login";

const authStore = useAuthStore();
const mainStore = useMainStore();

const router = useRouter();

const register = async (request: LoginRequest) => {
  const success = await authStore.register(request);
  if (success) {
    router.push({ name: "browse" });
  }
};
</script>

<template>
  <main :class="`theme-${mainStore.settings.theme}`">
    <MainLayout>
      <div class="content">
        <div class="title">Register</div>
        <RegisterForm @register="register" />
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
  gap: 1rem;
}

.title {
  font-size: 2rem;
}
</style>
