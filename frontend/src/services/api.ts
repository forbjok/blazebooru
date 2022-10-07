import axios from "axios";

import type { Post, PostInfo } from "@/models/api/post";
import type { BlazeBooruAuthService } from "./auth";

export class BlazeBooruApiService {
  constructor(private auth: BlazeBooruAuthService) {}

  async get_post(id: number) {
    try {
      const res = await axios.get<Post>(`/api/post/${id}`);

      return res.data;
    } catch {
      return;
    }
  }

  async get_posts() {
    try {
      const res = await axios.get<Post[]>("/api/post");

      return res.data;
    } catch {
      return;
    }
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
