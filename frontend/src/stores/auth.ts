import { computed, ref } from "vue";
import { defineStore } from "pinia";
import { useStorage } from "@vueuse/core";
import axios from "axios";

import type { LoginRequest, LoginResponse } from "@/models/api/login";
import type { User } from "@/models/api/user";

// useStorage serializer that works with undefined,
// because the default one doesn't.
const serializer = {
  read: (v: any) => (v ? JSON.parse(v) : undefined),
  write: (v: any) => (v ? JSON.stringify(v) : ""),
};

export const useAuthStore = defineStore("auth", () => {
  const auth = useStorage<LoginResponse | undefined>("bb_auth", undefined, undefined, { serializer });
  const userProfile = ref<User>();

  const isAuthorized = computed(() => !!auth.value?.access_token);
  const isAdmin = computed(() => (userProfile.value?.rank || -1) > 0);

  async function getAccessToken() {
    if (!(await refreshIfNeeded())) {
      return;
    }

    return auth.value?.access_token;
  }

  async function getAuthHeaders() {
    const accessToken = await getAccessToken();

    return {
      Authorization: `Bearer ${accessToken}`,
    };
  }

  async function login(request: LoginRequest) {
    try {
      const response = await axios.post<LoginResponse>(`/api/auth/login`, request);
      auth.value = response.data;

      await getUserProfile();
      return true;
    } catch {
      clearAuth();
      return false;
    }
  }

  async function register(request: LoginRequest) {
    try {
      const response = await axios.post<LoginResponse>("/api/user/register", request);
      auth.value = response.data;

      await getUserProfile();
      return true;
    } catch {
      clearAuth();
      return false;
    }
  }

  async function refreshIfNeeded(): Promise<boolean> {
    if (!auth.value) {
      return false;
    }

    const now = Date.now() / 1000 - 60;

    // If token is within 1 minute of expiring, refresh
    if (auth.value.exp < now) {
      if (!(await refresh())) {
        return false;
      }
    }

    return true;
  }

  async function getUserProfile() {
    if (!auth.value?.access_token) {
      return;
    }

    try {
      const res = await axios.get<User>(`/api/user/profile`, {
        headers: await getAuthHeaders(),
      });

      userProfile.value = res.data;
    } catch {
      userProfile.value = undefined;
    }
  }

  async function logout() {
    if (!isAuthorized.value) {
      return;
    }

    await axios.post("/api/auth/logout", undefined, {
      headers: await getAuthHeaders(),
    });

    clearAuth();
  }

  async function refresh() {
    const data = {
      refresh_token: auth.value?.refresh_token,
    };

    try {
      const response = await axios.post<LoginResponse>("/api/auth/refresh", data);
      auth.value = response.data;
      return true;
    } catch {
      clearAuth();
      return false;
    }
  }

  function clearAuth() {
    auth.value = undefined;
    userProfile.value = undefined;
  }

  getUserProfile();

  return { isAuthorized, isAdmin, userProfile, getAccessToken, getAuthHeaders, login, logout, register };
});
