<script setup lang="ts">
import { computed, onMounted, ref, shallowRef, toRefs, watch } from "vue";
import { useRoute, useRouter } from "vue-router";

import MainLayout from "@/components/MainLayout.vue";
import PostComment from "@/components/comment/PostComment.vue";
import Image from "@/components/common/Image.vue";
import PostInfo from "@/components/post/PostInfo.vue";

import { useAuthStore } from "@/stores/auth";
import { useMainStore } from "@/stores/main";
import { usePostStore } from "@/stores/post";

import type { Comment } from "@/models/api/comment";
import type { Post as PostModel, UpdatePost } from "@/models/api/post";
import { make_image_path } from "@/utils/path";
import { onKeyDown, useSwipe } from "@vueuse/core";

const props = defineProps<{
  id: number;
}>();

const { id } = toRefs(props);

const route = useRoute();
const router = useRouter();

const authStore = useAuthStore();
const mainStore = useMainStore();
const postStore = usePostStore();

const post = ref<PostModel>();
const comments = ref<Comment[]>([]);
const expand_image = ref(false);

const can_edit_post = computed(() => authStore.isAdmin || authStore.userProfile?.id === post.value?.user_id);
const can_edit_tags = computed(() => authStore.isAuthorized);

const file_url = computed(() => {
  if (!post.value) {
    return;
  }

  return make_image_path(post.value);
});

const expandedImage = shallowRef<HTMLDivElement | null>(null);

watch(route, () => {
  fetchPost();
});

onMounted(async () => {
  try {
    await fetchPost();
  } catch {
    router.replace({ name: "browse", query: { p: mainStore.currentPage } });
    return;
  }
});

const fetchPost = async () => {
  post.value = await mainStore.getPost(id.value);
  comments.value = await postStore.getPostComments(id.value);
};

const updatePost = async (update_post: UpdatePost) => {
  // If user is not allowed to edit the post info,
  // remove everything except the tags.
  if (!can_edit_post.value) {
    update_post = {
      add_tags: update_post.add_tags,
      remove_tags: update_post.remove_tags,
    };
  }

  await mainStore.updatePost(id.value, update_post);
  await fetchPost();
};

const deletePost = async () => {
  await mainStore.deletePost(id.value);

  // Navigate back to the browse view
  router.push({ name: "browse" });
};

const postComment = async () => {
  const comment = await postStore.postNewComment(id.value);

  // Add new comment to the list
  comments.value.push(comment);
};

const clickTag = async (tag: string) => {
  await mainStore.searchPosts({ tags: [tag], exclude_tags: [] });
  router.push({ name: "browse" });
};

const navigatePost = async (v: number) => {
  if (v === 0) {
    return;
  }

  const curr_post_index = mainStore.currentPosts.findIndex((p) => p.id === id.value);
  let to_post_index = curr_post_index + v;

  if (to_post_index < 0) {
    if (mainStore.currentPage <= 1) {
      return;
    }

    await mainStore.loadPage(mainStore.currentPage - 1);
    to_post_index = mainStore.currentPosts.length + to_post_index;
  } else if (to_post_index >= mainStore.currentPosts.length) {
    to_post_index = to_post_index - mainStore.currentPosts.length;
    await mainStore.loadPage(mainStore.currentPage + 1);
  }

  const to_post_id = mainStore.currentPosts[to_post_index].id;

  router.push({ name: "post", params: { id: to_post_id } });
};

onKeyDown("ArrowLeft", async (e) => {
  if (!expand_image.value || e.ctrlKey) {
    return;
  }

  e.preventDefault();
  navigatePost(-1);
});

onKeyDown("ArrowRight", async (e) => {
  if (!expand_image.value || e.ctrlKey) {
    return;
  }

  e.preventDefault();
  navigatePost(1);
});

const { direction } = useSwipe(expandedImage, {
  onSwipeEnd(e: TouchEvent) {
    if (direction.value === "left") {
      e.preventDefault();
      navigatePost(1);
    } else if (direction.value === "right") {
      e.preventDefault();
      navigatePost(-1);
    }
  },
});
</script>

<template>
  <main>
    <MainLayout>
      <!-- Desktop -->
      <div class="layout desktop">
        <div class="layout-side">
          <PostInfo
            v-if="post"
            :post="post"
            :can_edit_post="can_edit_post"
            :can_edit_tags="can_edit_tags"
            @clickTag="clickTag"
            @delete="deletePost"
            @update="updatePost"
          />
          <label>Comments</label>
          <div class="post-comments">
            <PostComment v-for="c in comments" :key="c.id" :comment="c" />
          </div>
          <form class="comment-form" @submit.prevent="postComment">
            <textarea
              class="comment-field"
              name="comment"
              v-model="postStore.newComment"
              placeholder="Comment"
              wrap="soft"
            ></textarea>

            <div class="form-buttons">
              <input
                class="post-button"
                type="submit"
                value="Post comment"
                :disabled="!postStore.newComment"
              />
            </div>
          </form>
        </div>
        <div class="layout-content">
          <div
            class="image-container"
            @click.prevent="expand_image = !expand_image"
          >
            <a :href="file_url">
              <Image :src="file_url" alt="Image" />
            </a>
          </div>
        </div>
      </div>

      <!-- Mobile -->
      <div class="layout mobile">
        <div
          class="image-container"
          @click.prevent="expand_image = !expand_image"
        >
          <a :href="file_url">
            <Image :src="file_url" alt="Image" />
          </a>
        </div>
        <div class="post-info">
          <PostInfo
            v-if="post"
            :post="post"
            :can_edit_post="can_edit_post"
            @clickTag="clickTag"
            @delete="deletePost"
            @update="updatePost"
          />
          <label>Comments</label>
          <div class="post-comments">
            <PostComment v-for="c in comments" :key="c.id" :comment="c" />
          </div>
          <form class="comment-form" @submit.prevent="postComment">
            <textarea
              class="comment-field"
              name="comment"
              v-model="postStore.newComment"
              placeholder="Comment"
              wrap="soft"
            ></textarea>

            <div class="form-buttons">
              <input
                class="post-button"
                type="submit"
                value="Post comment"
                :disabled="!postStore.newComment"
              />
            </div>
          </form>
        </div>
      </div>

      <!-- Expanded image -->
      <div
        ref="expandedImage"
        v-if="expand_image"
        class="expanded-image"
        @click.prevent="expand_image = false"
      >
        <a :href="file_url">
          <Image :src="file_url" alt="Image" />
        </a>
      </div>
    </MainLayout>
  </main>
</template>

<style scoped lang="scss">
.post-comments {
  display: flex;
  flex-direction: column;
  align-items: start;
  gap: 0.4rem;
}

.image-container {
  background-color: var(--color-post-background);
  padding: 0.2rem;

  a {
    display: block;
  }
}

.expanded-image {
  display: flex;
  align-items: center;
  justify-content: center;

  position: fixed;
  left: 0;
  right: 0;
  top: 0;
  bottom: 0;
  z-index: 999;

  background-color: var(--color-post-background);

  a {
    display: block;
  }

  .image {
    max-width: 100vw;
    max-height: 100vh;
  }
}

// --- Comment form ---
.comment-form {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;

  .comment-field {
    resize: vertical;

    width: 30rem;
    height: 5rem;

    width: 100%;
    min-height: 2rem;
  }

  .form-buttons {
    display: flex;
    flex-direction: row;
    align-self: end;
    gap: 1rem;
  }
}

.layout.desktop {
  display: flex;
  flex-direction: row;

  .layout-side {
    flex-shrink: 1;

    display: flex;
    flex-direction: column;
    gap: 1rem;

    background-color: var(--color-panel-background);
    border-right: 1px solid var(--color-divider);

    padding: 1rem;

    width: 25%;
    min-width: 18rem;
    min-height: var(--max-content-height);
  }

  .layout-content {
    display: flex;
    flex-direction: column;
    gap: 0.2rem;

    padding-top: 1rem;
    padding-left: 1rem;
  }

  .image-container .image {
    max-width: 90vw;
    max-height: 92vh;
  }
}

.layout.mobile {
  display: flex;
  flex-direction: column;
  gap: 1rem;

  .post-info {
    display: flex;
    flex-direction: column;
    gap: 0.4rem;

    padding: 0.4rem;

    max-width: 100vw;
    overflow: hidden;
  }

  .image-container .image {
    max-width: 100vw;
    max-height: var(--max-content-height);
  }
}
</style>
