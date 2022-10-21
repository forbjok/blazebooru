import { createRouter, createWebHistory } from "vue-router";

import LoginView from "@/views/LoginView.vue";
import RegisterView from "@/views/RegisterView.vue";
import PostView from "@/views/PostView.vue";
import BrowseView from "@/views/BrowseView.vue";
import UploadView from "@/views/UploadView.vue";

const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  scrollBehavior(to, from, savedPosition) {
    if (savedPosition) {
      return savedPosition;
    }
  },
  routes: [
    {
      path: "/",
      redirect: { name: "browse" },
    },
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
      path: "/browse",
      name: "browse",
      component: BrowseView,
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
