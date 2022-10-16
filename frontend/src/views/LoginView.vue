<script setup lang="ts">
import { useRouter } from "vue-router";

import MainLayout from "@/components/MainLayout.vue";
import LoginForm from "@/components/login/LoginForm.vue";

import type { LoginRequest } from "@/models/api/login";
import { useAuthStore } from "@/stores/auth";
import { useMainStore } from "@/stores/main";

const router = useRouter();

const authStore = useAuthStore();
const mainStore = useMainStore();

const login = async (request: LoginRequest) => {
  const success = await authStore.login(request);
  if (success) {
    router.push({ name: "browse" });
  }
};
</script>

<template>
  <main :class="`theme-${mainStore.settings.theme}`">
    <MainLayout>
      <div class="content">
        <div class="title">Login</div>
        <LoginForm @log-in="login" />
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
