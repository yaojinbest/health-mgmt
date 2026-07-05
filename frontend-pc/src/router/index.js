import { createRouter, createWebHistory } from 'vue-router'
import { useUserStore } from '@/stores/user'

const routes = [
  {
    path: '/login',
    name: 'Login',
    component: () => import('@/views/Login.vue'),
    meta: { public: true }
  },
  {
    path: '/',
    component: () => import('@/layout/MainLayout.vue'),
    redirect: '/dashboard',
    children: [
      {
        path: 'dashboard',
        name: 'Dashboard',
        component: () => import('@/views/Dashboard.vue'),
        meta: { title: '概览', icon: 'DataLine' }
      },
      {
        path: 'users',
        name: 'Users',
        component: () => import('@/views/Users.vue'),
        meta: { title: '用户管理', icon: 'User', requireAdmin: true }
      },
      {
        path: 'medical',
        name: 'Medical',
        component: () => import('@/views/Medical.vue'),
        meta: { title: '医疗资源', icon: 'FirstAidKit' }
      },
      {
        path: 'health',
        name: 'Health',
        component: () => import('@/views/Health.vue'),
        meta: { title: '健康数据', icon: 'DataAnalysis' }
      },
      {
        path: 'medicine',
        name: 'Medicine',
        component: () => import('@/views/Medicine.vue'),
        meta: { title: '用药管理', icon: 'MagicStick' }
      },
      {
        path: 'consultation',
        name: 'Consultation',
        component: () => import('@/views/Consultation.vue'),
        meta: { title: '在线咨询', icon: 'ChatLineRound' }
      },
      {
        path: 'articles',
        name: 'Articles',
        component: () => import('@/views/Articles.vue'),
        meta: { title: '健康文章', icon: 'Document' }
      }
    ]
  }
]

const router = createRouter({
  history: createWebHistory(),
  routes
})

router.beforeEach((to, from, next) => {
  const userStore = useUserStore()
  if (to.meta.public) return next()
  if (!userStore.isLoggedIn) return next('/login')
  if (to.meta.requireAdmin && !userStore.isAdmin) {
    return next('/dashboard')
  }
  next()
})

export default router