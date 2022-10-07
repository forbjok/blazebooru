import { createRouter, createWebHistory } from "vue-router";

import LoginView from "@/views/LoginView.vue";
import RegisterView from "@/views/RegisterView.vue";
import PostView from "@/views/PostView.vue";
import PostsView from "@/views/PostsView.vue";
import UploadView from "@/views/UploadView.vue";

const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  scrollBehavior(to, from, savedPosition) {
    if (savedPosition) {
      return new Promise((resolve) => {
        setTimeout(() => {
          resolve(savedPosition);
        }, 1000);
      });
    }
  },
  routes: [
    {
      path: "/login",
      name: "login",
      component: LoginView,
    },
    {
      path: "/register",
      name: "register",
      component: RegisterView,
    },
    {
      path: "/posts",
      name: "posts",
      component: PostsView,
    },
    {
      path: "/post/:id",
      name: "post",
      component: PostView,
      props: (r) => {
        return {
          ...r.params,
          id: Number(r.params.id),
        };
      },
    },
    {
      path: "/upload",
      name: "upload",
      component: UploadView,
    },
  ],
});

export default router;
