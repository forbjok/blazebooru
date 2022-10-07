import axios from "axios";
import { ref } from "vue";

import type { LocalStorageService } from "@/services/local-storage";

import type { LoginRequest, LoginResponse } from "@/models/api/login";
import type { User } from "@/models/api/user";

const AUTH_KEY_NAME = "bb_auth";

export class BlazeBooruAuthService {
  public readonly isAuthorized = ref(false);
  public readonly userProfile = ref<User>();

  private auth?: LoginResponse;

  constructor(private localStorage: LocalStorageService) {}

  async setup() {
    await this.loadAuth();
    await this.getUserProfile();
  }

  async getAccessToken(): Promise<string | undefined> {
    if (!(await this.refreshIfNeeded())) {
      return;
    }

    return this.auth?.access_token;
  }

  async getAuthHeaders() {
    const access_token = await this.getAccessToken();

    return {
      Authorization: `Bearer ${access_token}`,
    };
  }

  async setAuth(auth?: LoginResponse) {
    this.auth = auth;
    this.saveAuth();
  }

  async login(request: LoginRequest): Promise<boolean> {
    try {
      const response = await axios.post<LoginResponse>(`/api/auth/login`, request);
      this.auth = response.data;
      this.saveAuth();

      await this.getUserProfile();
      return true;
    } catch {
      this.clearAuth();
      return false;
    }
  }

  async register(request: LoginRequest): Promise<boolean> {
    try {
      const response = await axios.post<LoginResponse>("/api/user/register", request);
      this.auth = response.data;
      this.saveAuth();

      await this.getUserProfile();
      return true;
    } catch {
      this.clearAuth();
      return false;
    }
  }

  async logout() {
    if (!this.isAuthorized.value) {
      return;
    }

    await axios.post<LoginResponse>("/api/auth/logout", undefined, {
      headers: await this.getAuthHeaders(),
    });

    this.clearAuth();
  }

  private async refresh(): Promise<boolean> {
    const data = {
      refresh_token: this.auth?.refresh_token,
    };

    try {
      const response = await axios.post<LoginResponse>("/api/auth/refresh", data);
      this.auth = response.data;
      this.saveAuth();
      return true;
    } catch {
      this.clearAuth();
      return false;
    }
  }

  private async refreshIfNeeded(): Promise<boolean> {
    if (!this.auth) {
      return false;
    }

    const now = Date.now() / 1000 - 60;

    // If token is within 1 minute of expiring, refresh
    if (this.auth.exp < now) {
      if (!(await this.refresh())) {
        return false;
      }
    }

    return true;
  }

  private clearAuth() {
    this.auth = undefined;
    this.userProfile.value = undefined;
    this.isAuthorized.value = false;
    this.saveAuth();
  }

  private async getUserProfile() {
    if (!this.auth?.access_token) {
      return;
    }

    try {
      const res = await axios.get<User>(`/api/user/profile`, {
        headers: {
          Authorization: `Bearer ${this.auth?.access_token}`,
        },
      });

      this.isAuthorized.value = true;
      this.userProfile.value = res.data;
    } catch {
      this.isAuthorized.value = false;
      this.userProfile.value = undefined;
    }
  }

  private async loadAuth() {
    this.auth = this.localStorage.get<LoginResponse>(AUTH_KEY_NAME);
  }

  private saveAuth() {
    this.localStorage.set(AUTH_KEY_NAME, this.auth);
  }
}
