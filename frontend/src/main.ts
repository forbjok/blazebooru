import { createApp } from "vue";
import { createPinia } from "pinia";

import App from "./App.vue";
import router from "./router";

// CSS reset
import "ress";

// Font-awesome
import "@fortawesome/fontawesome-free/js/fontawesome";
import "@fortawesome/fontawesome-free/js/regular";
import "@fortawesome/fontawesome-free/js/solid";

// Import main stylesheet
import "@/styles/main.scss";

// Import other stylesheets
import "@/styles/base.scss";
import "@/styles/mobile.scss";
import "@/styles/theme/dark.scss";
import "@/styles/theme/blue.scss";

const app = createApp(App);

app.use(createPinia());
app.use(router);

app.mount("#app");
