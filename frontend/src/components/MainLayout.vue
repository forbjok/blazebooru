<script setup lang="ts">
import { useAuthStore } from "@/stores/auth";

const authStore = useAuthStore();

const logout = async () => {
  await authStore.logout();
};
</script>

<template>
  <div class="layout">
    <div class="header-bar">
      <span class="powered-by">Powered by BlazeBooru</span>
      <span class="nav">
        <span class="posts"> [ <router-link :to="{ name: 'posts' }">Posts</router-link> ] </span>
        <span v-if="authStore.isAuthorized" class="upload">
          [ <router-link :to="{ name: 'upload' }">Upload</router-link> ]
        </span>
      </span>
      <span v-if="authStore.isAuthorized" class="user-authorized">
        <span class="username"><i class="fa-solid fa-user"></i> {{ authStore.userProfile?.name }}</span>
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
  padding-top: 2rem;

  min-height: 100vh;
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

  .nav {
    flex-grow: 1;
  }

  .powered-by {
    position: absolute;
    top: 0.3rem;
    left: 0;
    right: 0;

    color: var(--color-faded-text);
    text-align: center;

    font-size: 0.9rem;

    z-index: -8;
  }
  .user {
    flex-shrink: 1;
  }

  .username {
    padding-right: 1rem;
  }
}
</style>
