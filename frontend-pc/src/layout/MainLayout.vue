<template>
  <el-container class="main-layout">
    <el-aside :width="collapsed ? '64px' : '220px'" class="sidebar">
      <div class="logo">
        <el-icon size="24" color="#fff"><FirstAidKit /></el-icon>
        <span v-if="!collapsed" class="logo-text">健康管理系统</span>
      </div>
      <el-menu
        :default-active="activeRoute"
        :collapse="collapsed"
        background-color="#001529"
        text-color="#c9d1d9"
        active-text-color="#409EFF"
        router
      >
        <el-menu-item
          v-for="item in menuItems"
          :key="item.path"
          :index="item.path"
        >
          <el-icon><component :is="item.icon" /></el-icon>
          <template #title>{{ item.title }}</template>
        </el-menu-item>
      </el-menu>
    </el-aside>

    <el-container>
      <el-header class="header">
        <div class="header-left">
          <el-icon size="18" class="collapse-btn" @click="collapsed = !collapsed">
            <Fold v-if="!collapsed" /><Expand v-else />
          </el-icon>
          <span class="page-title">{{ currentTitle }}</span>
        </div>
        <div class="header-right">
          <el-dropdown @command="onCommand">
            <span class="user-info">
              <el-icon><UserFilled /></el-icon>
              {{ userStore.user?.realName || userStore.user?.username }}
              <el-tag v-if="userStore.user?.role" size="small" :type="roleTagType">
                {{ roleLabel }}
              </el-tag>
            </span>
            <template #dropdown>
              <el-dropdown-menu>
                <el-dropdown-item command="logout">退出登录</el-dropdown-item>
              </el-dropdown-menu>
            </template>
          </el-dropdown>
        </div>
      </el-header>

      <el-main class="main">
        <router-view />
      </el-main>
    </el-container>
  </el-container>
</template>

<script setup>
import { computed, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useUserStore } from '@/stores/user'
import { ElMessage } from 'element-plus'

const route = useRoute()
const router = useRouter()
const userStore = useUserStore()
const collapsed = ref(false)

const menuItems = computed(() => {
  return router.options.routes
    .find(r => r.path === '/')?.children
    ?.filter(item => !item.meta?.requireAdmin || userStore.isAdmin)
    .map(item => ({
      path: '/' + item.path,
      title: item.meta?.title || item.name,
      icon: item.meta?.icon || 'Document'
    })) || []
})

const activeRoute = computed(() => '/' + (route.path.split('/')[1] || 'dashboard'))
const currentTitle = computed(() => {
  return menuItems.value.find(m => m.path === activeRoute.value)?.title || ''
})

const roleLabel = computed(() => {
  const r = userStore.user?.role
  return r === 'ADMIN' ? '管理员' : r === 'DOCTOR' ? '医生' : r === 'USER' ? '患者' : r
})
const roleTagType = computed(() => {
  const r = userStore.user?.role
  return r === 'ADMIN' ? 'danger' : r === 'DOCTOR' ? 'warning' : 'success'
})

function onCommand(cmd) {
  if (cmd === 'logout') {
    userStore.logout()
    ElMessage.success('已退出登录')
    router.push('/login')
  }
}
</script>

<style scoped>
.main-layout { height: 100vh; }
.sidebar {
  background: #001529;
  transition: width 0.2s;
  overflow: hidden;
}
.logo {
  height: 60px;
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 0 20px;
  color: #fff;
  font-weight: 600;
  font-size: 16px;
  border-bottom: 1px solid #1f3a5a;
}
.logo-text { white-space: nowrap; }

.header {
  background: #fff;
  border-bottom: 1px solid var(--border-color);
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0 20px;
}
.header-left {
  display: flex;
  align-items: center;
  gap: 16px;
}
.collapse-btn { cursor: pointer; }
.page-title {
  font-size: 16px;
  font-weight: 600;
}
.user-info {
  display: flex;
  align-items: center;
  gap: 6px;
  cursor: pointer;
  font-size: 14px;
}
.main {
  background: #f5f7fa;
  padding: 0;
}
:deep(.el-menu) { border-right: none; }
</style>