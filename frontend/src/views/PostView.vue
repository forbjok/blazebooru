<script setup lang="ts">
import { computed, onMounted, ref, toRefs } from "vue";
import { useRouter } from "vue-router";

import PostComment from "../components/comment/PostComment.vue";
import MainLayout from "@/components/MainLayout.vue";
import PostInfo from "@/components/post/PostInfo.vue";

import { useAuthStore } from "@/stores/auth";
import { useMainStore } from "@/stores/main";
import { usePostStore } from "@/stores/post";

import type { Comment } from "@/models/api/comment";
import type { Post as PostModel, UpdatePost } from "@/models/api/post";
import { make_image_path } from "@/utils/path";

const props = defineProps<{
  id: number;
}>();

const { id } = toRefs(props);

const router = useRouter();

const authStore = useAuthStore();
const mainStore = useMainStore();
const postStore = usePostStore();

const post = ref<PostModel>();
const comments = ref<Comment[]>([]);
const expand_image = ref(false);

const can_edit = computed(() => authStore.userProfile?.id === post.value?.user_id);

const file_url = computed(() => {
  if (!post.value) {
    return;
  }

  return make_image_path(post.value);
});

onMounted(async () => {
  await fetchPost();
});

const fetchPost = async () => {
  post.value = await mainStore.getPost(id.value);
  comments.value = await postStore.getPostComments(id.value);
};

const updatePost = async (update_post: UpdatePost) => {
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
</script>

<template>
  <main :class="`theme-${mainStore.settings.theme}`">
    <MainLayout>
      <!-- Desktop -->
      <div class="layout desktop">
        <div class="layout-side">
          <PostInfo v-if="post" :post="post" :can_edit="can_edit" @delete="deletePost" @update="updatePost" />
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
              <input class="post-button" type="submit" value="Post comment" :disabled="!postStore.newComment" />
            </div>
          </form>
        </div>
        <div class="layout-content">
          <div class="image" :class="{ expand: expand_image }" @click.prevent="expand_image = !expand_image">
            <a :href="file_url">
              <img :src="file_url" alt="Image" />
            </a>
          </div>
        </div>
      </div>

      <!-- Mobile -->
      <div class="layout mobile">
        <div class="image">
          <a :href="file_url" target="_blank">
            <img :src="file_url" alt="Image" />
          </a>
        </div>
        <div class="post-info">
          <PostInfo v-if="post" :post="post" :can_edit="can_edit" @delete="deletePost" @update="updatePost" />
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
              <input class="post-button" type="submit" value="Post comment" :disabled="!postStore.newComment" />
            </div>
          </form>
        </div>
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

.image {
  a {
    display: block;
  }

  img {
    background-color: var(--color-post-background);

    padding: 0.2rem;
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

  .image {
    &:not(.expand) img {
      max-width: 90vw;
      max-height: 92vh;
    }
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

  .image img {
    max-width: 100vw;
    max-height: var(--max-content-height);
  }
}
</style>
