import { createApp, ref } from "vue";
import App from "./App.vue";
import router from "./router";

import { DEFAULT_SETTINGS, type Settings } from "./models/settings";
import { BlazeBooruApiService } from "./services/api";
import { BlazeBooruAuthService } from "./services/auth";
import { LocalStorageService } from "./services/local-storage";
import { PathService } from "./services/path";

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

app.use(router);

const localStorage = new LocalStorageService();
const auth = new BlazeBooruAuthService(localStorage);
const api = new BlazeBooruApiService(auth);
const path = new PathService();
const settings = ref<Settings>({ ...DEFAULT_SETTINGS });

app.provide("api", api);
app.provide("auth", auth);
app.provide("path", path);
app.provide("settings", settings);

app.mount("#app");
