<script setup lang="ts">
import { useRouter } from "vue-router";

import { useAuthStore } from "@/stores/auth";
import { useMainStore } from "@/stores/main";
import { useUploadStore } from "@/stores/upload";

const router = useRouter();

const authStore = useAuthStore();
const mainStore = useMainStore();
const uploadStore = useUploadStore();

const logout = async () => {
  await authStore.logout();

  const sysConfig = await mainStore.getSysConfig();
  if (sysConfig.require_login) {
    router.replace({ name: "login" });
    return;
  }
};
</script>

<template>
  <div class="layout">
    <div class="header-bar">
      <span class="nav">
        <span class="browse"> [ <router-link :to="{ name: 'browse' }">Browse</router-link> ] </span>
        <span v-if="authStore.isAuthorized" class="upload">
          [ <router-link :to="{ name: 'upload' }">Upload</router-link> ] [
          <router-link :to="{ name: 'multiupload' }">Multi-Upload</router-link> ]
        </span>
        <span v-if="uploadStore.isUploading" class="upload-status">
          [ <router-link :to="{ name: 'upload-progress' }">UPLOADING...</router-link> ]
        </span>
        <span v-if="authStore.isAdmin" class="tags admin">
          [ <router-link :to="{ name: 'tags' }">Tags</router-link> ]
        </span>
      </span>
      <span v-if="authStore.isAuthorized" class="user-authorized">
        <span class="username" :class="{ admin: authStore.isAdmin }"
          ><span v-if="!authStore.isAdmin"><i class="fa-solid fa-user"></i></span
          ><span v-if="authStore.isAdmin"><i class="fa-solid fa-crown"></i></span>
          {{ authStore.userProfile?.name }}</span
        >
        <span class="logout"> [ <button class="link-button" @click="logout">Log out</button> ] </span>
      </span>
      <span v-if="!authStore.isAuthorized" class="user-unauthorized">
        <span class="login"> [ <router-link :to="{ name: 'login' }">Login</router-link> ] </span>
        <span class="register"> [ <router-link :to="{ name: 'register' }">Register</router-link> ] </span>
      </span>
    </div>
    <div class="content">
      <slot></slot>
    </div>
  </div>
</template>

<style scoped lang="scss">
.layout {
  --top-bar-height: 2rem;
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
