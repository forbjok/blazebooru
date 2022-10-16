import { ref } from "vue";
import { defineStore } from "pinia";
import axios from "axios";

import { useAuthStore } from "./auth";

import type { Comment } from "@/models/api/comment";
import type { Post } from "@/models/api/post";
import type { NewPostComment } from "@/models/api/comment";

export const usePostStore = defineStore("post", () => {
  const authStore = useAuthStore();

  const newComment = ref("");

  async function getPost(id: number) {
    const res = await axios.get<Post>(`/api/post/${id}`);
    return res.data;
  }

  async function getPostComments(post_id: number) {
    const res = await axios.get<Comment[]>(`/api/post/${post_id}/comments`);
    return res.data;
  }

  async function postNewComment(post_id: number) {
    const model = {
      comment: newComment.value,
    };

    const comment = await createComment(post_id, model);

    newComment.value = "";

    return comment;
  }

  async function createComment(post_id: number, comment: NewPostComment) {
    const res = await axios.post<Comment>(`/api/post/${post_id}/comments/new`, comment, {
      headers: await authStore.getAuthHeaders(),
    });

    return res.data;
  }

  return {
    newComment,
    getPost,
    getPostComments,
    postNewComment,
  };
});
