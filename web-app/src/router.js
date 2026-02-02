import { createRouter, createWebHistory } from "vue-router";
import HomeView from "./views/HomeView.vue";
import DashboardView from "./views/DashboardView.vue";
import OperadoraDetailsView from "./views/OperadoraDetailsView.vue";

const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  routes: [
    {
      path: "/",
      name: "home",
      component: HomeView,
    },
    {
      path: "/dashboard",
      name: "dashboard",
      component: DashboardView,
    },
    {
      path: "/operadora/:cnpj",
      name: "operadora-details",
      component: OperadoraDetailsView,
    },
  ],
});

export default router;
