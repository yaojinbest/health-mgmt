<template>
  <div class="login-page">
    <div class="login-box">
      <div class="login-header">
        <el-icon size="48" color="#409EFF"><FirstAidKit /></el-icon>
        <h2>健康管理系统</h2>
        <p>PC 桌面端 (管理员控制台)</p>
      </div>
      <el-form :model="form" :rules="rules" ref="formRef" @submit.prevent="onSubmit" label-position="top">
        <el-form-item label="账号" prop="username">
          <el-input v-model="form.username" placeholder="admin / user_wang / doctor_zhang" size="large" />
        </el-form-item>
        <el-form-item label="密码" prop="password">
          <el-input v-model="form.password" type="password" placeholder="root" show-password size="large" />
        </el-form-item>
        <el-form-item>
          <el-button type="primary" size="large" :loading="loading" @click="onSubmit" style="width: 100%">
            登录
          </el-button>
        </el-form-item>
        <div class="login-hint">
          <el-text type="info" size="small">
            演示账号: admin / root · user_wang / root · doctor_zhang / root
          </el-text>
        </div>
      </el-form>
    </div>
  </div>
</template>

<script setup>
import { ref, reactive } from 'vue'
import { useRouter } from 'vue-router'
import { ElMessage } from 'element-plus'
import { useUserStore } from '@/stores/user'

const router = useRouter()
const userStore = useUserStore()
const formRef = ref(null)
const loading = ref(false)

const form = reactive({
  username: 'admin',
  password: 'root'
})

const rules = {
  username: [{ required: true, message: '请输入账号', trigger: 'blur' }],
  password: [{ required: true, message: '请输入密码', trigger: 'blur' }]
}

async function onSubmit() {
  await formRef.value.validate(async (valid) => {
    if (!valid) return
    loading.value = true
    try {
      await userStore.login(form.username, form.password)
      ElMessage.success(`欢迎回来, ${userStore.user?.realName || form.username}`)
      router.push('/dashboard')
    } catch (e) {
      // 错误消息已由 http interceptor 处理
    } finally {
      loading.value = false
    }
  })
}
</script>

<style scoped>
.login-page {
  height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
}
.login-box {
  width: 420px;
  padding: 40px;
  background: #fff;
  border-radius: 12px;
  box-shadow: 0 8px 24px rgba(0, 0, 0, 0.15);
}
.login-header {
  text-align: center;
  margin-bottom: 32px;
}
.login-header h2 {
  margin: 12px 0 4px;
  font-size: 22px;
  color: var(--text-primary);
}
.login-header p {
  margin: 0;
  font-size: 13px;
  color: var(--text-secondary);
}
.login-hint {
  text-align: center;
  margin-top: 8px;
}
</style>