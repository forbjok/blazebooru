import axios from "axios";

import type { PaginationStats, Post, PostInfo } from "@/models/api/post";
import type { BlazeBooruAuthService } from "./auth";

export class BlazeBooruApiService {
  constructor(private auth: BlazeBooruAuthService) {}

  async get_post(id: number) {
    const res = await axios.get<Post>(`/api/post/${id}`);

    return res.data;
  }

  async search_posts(include_tags: string[], exclude_tags: string[], offset: number, limit: number) {
    const t = include_tags.join(",") || undefined;
    const e = exclude_tags.join(",") || undefined;

    const res = await axios.get<Post[]>("/api/post/search", {
      params: {
        t,
        e,
        offset,
        limit,
      },
    });

    return res.data;
  }

  async get_posts_pagination_stats(include_tags: string[], exclude_tags: string[]) {
    const t = include_tags.join(",") || undefined;
    const e = exclude_tags.join(",") || undefined;

    const res = await axios.get<PaginationStats>("/api/post/stats", {
      params: {
        t,
        e,
      },
    });

    return res.data;
  }

  async upload_post(info: PostInfo, file: File) {
    const formData = new FormData();

    formData.append("info", JSON.stringify(info));
    formData.append("file", file, file.name);

    const res = await axios.post<Post>("/api/post/upload", formData, {
      headers: await this.auth.getAuthHeaders(),
    });

    return res.data;
  }
}
