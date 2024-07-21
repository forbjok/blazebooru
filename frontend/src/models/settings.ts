export interface Settings {
  theme: string;
  posts_per_page: number;
}

export const DEFAULT_SETTINGS: Settings = {
  theme: "dark",
  posts_per_page: 32,
};
