import { ref } from "vue";
import { defineStore } from "pinia";
import axios from "axios";

import { useAuthStore } from "./auth";

import type { Post, PostInfo } from "@/models/api/post";

export interface UploadPost {
  file: File;
  info: PostInfo;
}

export interface QueuedUploadPost extends UploadPost {
  is_processed: boolean;
  is_uploading: boolean;
  progress: number;
  error_message?: string;
  post_id?: number;
}

export const useUploadStore = defineStore("upload", () => {
  const authStore = useAuthStore();

  const isUploading = ref<boolean>(false);

  const queuedPosts = ref<QueuedUploadPost[]>([]);

  function toQueuedUploadPost(post: UploadPost): QueuedUploadPost {
    return {
      ...post,
      is_processed: false,
      is_uploading: false,
      progress: 0,
    };
  }

  function queue(post: UploadPost) {
    const qp = toQueuedUploadPost(post);

    queuedPosts.value.push(qp);
  }

  function clearFinished() {
    queuedPosts.value = queuedPosts.value.filter((p) => !p.is_processed);
  }

  async function processUploadQueue() {
    if (isUploading.value) {
      return;
    }

    isUploading.value = true;
    clearFinished();

    const prevOnbeforeunload = window.onbeforeunload;
    window.onbeforeunload = () => {
      return false;
    };

    try {
      while (true) {
        const uploadPosts = [...queuedPosts.value.filter((p) => !p.is_processed)];
        if (uploadPosts.length < 1) {
          break;
        }

        var n = 0;

        for (const up of uploadPosts) {
          up.is_processed = true;
          up.is_uploading = true;

          console.log(`Uploading ${++n} of ${uploadPosts.length}:`, up.file.name);

          try {
            const formData = new FormData();

            formData.append("info", JSON.stringify(up.info));
            formData.append("file", up.file, up.file.name);

            const res = await axios.post<number>("/api/post/upload", formData, {
              headers: await authStore.getAuthHeaders(),
              onUploadProgress: (e) => {
                if (e.total) {
                  const percentComplete = Math.round((e.loaded / e.total) * 100);
                  up.progress = percentComplete;
                }
              },
            });

            up.post_id = res.data;
          } catch (err: any) {
            up.error_message = err;
          } finally {
            up.is_uploading = false;
          }
        }
      }
    } finally {
      window.onbeforeunload = prevOnbeforeunload;
      isUploading.value = false;
    }
  }

  return {
    isUploading,
    queuedPosts,
    queue,
    processUploadQueue,
  };
});
