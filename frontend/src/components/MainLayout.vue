<script setup lang="ts">
import { ref } from "vue";
import { useRouter } from "vue-router";

import { useAuthStore } from "@/stores/auth";
import { useMainStore } from "@/stores/main";
import { useUploadStore } from "@/stores/upload";
import { useResizeObserver } from "@vueuse/core";

const router = useRouter();

const authStore = useAuthStore();
const mainStore = useMainStore();
const uploadStore = useUploadStore();

const layoutRef = ref<HTMLDivElement>();
const headerBar = ref<HTMLElement>();

useResizeObserver(headerBar, () => {
  const height = headerBar.value?.offsetHeight;
  if (!height) {
    return;
  }

  layoutRef.value?.style.setProperty("--top-bar-height", `${height}px`);
});

const logout = async () => {
  await authStore.logout();

  if (mainStore.sysConfig?.require_login) {
    router.replace({ name: "login" });
    return;
  }
};
</script>

<template>
  <div ref="layoutRef" class="layout">
    <header ref="headerBar" class="header-bar">
      <nav class="nav">
        <span class="browse">
          [
          <router-link :to="{ name: 'browse' }">
            <i class="fa-solid fa-eye"></i>
            Browse
          </router-link>
          ]
        </span>
        <span v-if="authStore.isAuthorized" class="bar-item upload">
          [ <router-link :to="{ name: 'upload' }"><i class="fa-solid fa-upload"></i> Upload</router-link> ]
        </span>
        <span v-if="uploadStore.isUploading" class="bar-item upload-status">
          [
          <router-link :to="{ name: 'upload-progress' }">
            <i class="fa-solid fa-bars-progress"></i>
            Upload in progress...
          </router-link>
          ]
        </span>
        <span v-if="authStore.isAdmin" class="bar-item tags admin">
          [ <router-link :to="{ name: 'tags' }">Tags</router-link> ]
        </span>
      </nav>
      <span v-if="authStore.isAuthorized" class="user-authorized">
        <span class="username" :class="{ admin: authStore.isAdmin }">
          <span v-if="!authStore.isAdmin"><i class="fa-solid fa-user"></i></span>
          <span v-if="authStore.isAdmin"><i class="fa-solid fa-crown"></i></span>
          {{ authStore.userProfile?.name }}
        </span>
        <span class="bar-item logout">
          [
          <button class="link-button" @click="logout">
            <i class="fa-solid fa-right-from-bracket"></i>
            Log out
          </button>
          ]
        </span>
      </span>
      <span v-if="!authStore.isAuthorized" class="user-unauthorized">
        <span class="login">
          [
          <router-link :to="{ name: 'login' }">
            <i class="fa-solid fa-right-to-bracket"></i>
            Login
          </router-link>
          ]
        </span>
        <span v-if="mainStore.sysConfig?.allow_registration" class="register">
          [
          <router-link :to="{ name: 'register' }">
            <i class="fa-solid fa-pen"></i>
            Register
          </router-link>
          ]
        </span>
      </span>
    </header>
    <div class="content">
      <slot></slot>
    </div>
  </div>
</template>

<style scoped lang="scss">
.layout {
  --max-content-height: calc(100vh - var(--top-bar-height));

  padding-top: var(--top-bar-height);

  min-height: var(--max-content-height);
}

.header-bar {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;

  display: flex;
  flex-direction: row;

  padding: 0.3rem 0.5rem 0.4rem;

  z-index: 8;

  background: var(--color-headerbar-background);
  border: 1px solid var(--color-headerbar-border);
  border-bottom-width: 1px;
  box-shadow: -0.5rem 1px 1rem rgba(0, 0, 0, 0.2);
  color: var(--color-headerbar-text);

  cursor: default;

  .bar-item {
    white-space: nowrap;
  }

  .nav {
    flex-grow: 1;

    .admin {
      a {
        color: var(--color-username-admin);

        &:hover {
          filter: brightness(0.9);
        }
      }
    }
  }

  .user {
    flex-shrink: 1;
  }

  .username {
    padding-right: 1rem;

    &.admin {
      color: var(--color-username-admin);
    }
  }
}
</style>
