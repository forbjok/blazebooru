import { ref } from "vue";
import { defineStore } from "pinia";
import axios, { AxiosError } from "axios";

import { useAuthStore } from "./auth";

import type { PostInfo } from "@/models/api/post";

export interface StagedPost {
  file: File;
  title: string;
  description: string;
  source: string;
  tags: string[];
  previewUrl: string;
}

export interface QueuedUploadPost extends StagedPost {
  is_processed: boolean;
  is_uploading: boolean;
  progress: number;
  error_message?: string;
  post_id?: number;
}

export const useUploadStore = defineStore("upload", () => {
  const authStore = useAuthStore();

  const isUploading = ref<boolean>(false);

  const commonTags = ref<string[]>([]);
  const stagedPosts = ref<StagedPost[]>([]);
  const queuedPosts = ref<QueuedUploadPost[]>([]);

  function toQueuedUploadPost(post: StagedPost): QueuedUploadPost {
    return {
      ...post,
      is_processed: false,
      is_uploading: false,
      progress: 0,
    };
  }

  function stage(post: StagedPost) {
    stagedPosts.value.push(post);
  }

  function unstage(post: StagedPost) {
    const index = stagedPosts.value.findIndex((p) => p === post);
    if (index < 0) {
      return;
    }

    stagedPosts.value.splice(index, 1);
  }

  function queue(post: StagedPost) {
    const qp = toQueuedUploadPost(post);

    queuedPosts.value.push(qp);
  }

  function clearStaged() {
    stagedPosts.value = [];
  }

  function queueStaged() {
    const queuePosts = stagedPosts.value.map((p) => ({
      ...p,
      tags: [...commonTags.value, ...p.tags],
    }));

    queuePosts.forEach(queue);
    clearStaged();
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

            const info: PostInfo = {
              title: up.title,
              description: up.description,
              source: up.source,
              tags: up.tags,
            };

            formData.append("info", JSON.stringify(info));
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
            const _err = err as AxiosError;

            var msg: string;
            if (_err.response) {
              msg = _err.response.data as string;
            } else {
              msg = _err.message;
            }

            console.log("Upload failed:", msg);
            up.error_message = msg;
          } finally {
            up.is_uploading = false;
          }
        }
      }
    } finally {
      isUploading.value = false;
    }
  }

  function onBeforeUnload(e: BeforeUnloadEvent) {
    if (isUploading.value || stagedPosts.value.length > 0) {
      e.preventDefault();
    }
  }

  window.addEventListener("beforeunload", onBeforeUnload);

  return {
    isUploading,
    commonTags,
    stagedPosts,
    queuedPosts,
    stage,
    unstage,
    queue,
    clearStaged,
    queueStaged,
    processUploadQueue,
  };
});
