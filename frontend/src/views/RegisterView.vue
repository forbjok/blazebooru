<script setup lang="ts">
import { inject } from "vue";
import { useRouter } from "vue-router";

import MainLayout from "@/components/MainLayout.vue";
import RegisterForm from "@/components/RegisterForm.vue";

import type { Settings } from "@/models/settings";
import type { LoginRequest } from "@/models/api/login";
import type { BlazeBooruAuthService } from "@/services/auth";

const router = useRouter();

const auth = inject<BlazeBooruAuthService>("auth")!;
const settings = inject<Settings>("settings")!;

const register = async (request: LoginRequest) => {
  const success = await auth.register(request);
  if (success) {
    router.push({ name: "posts" });
  }
};
</script>

<template>
  <main :class="`theme-${settings.theme}`">
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
