export interface LoginRequest {
  name: string;
  password: string;
}

export interface LoginResponse {
  access_token: string;
  exp: number;
  refresh_token: string;
}
