import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import { authApi } from '@/api'

export const useUserStore = defineStore('user', () => {
  const token = ref(localStorage.getItem('pc_token') || '')
  const user = ref(JSON.parse(localStorage.getItem('pc_user') || 'null'))

  const isLoggedIn = computed(() => !!token.value)
  const isAdmin = computed(() => user.value?.role === 'ADMIN')
  const isDoctor = computed(() => user.value?.role === 'DOCTOR')

  async function login(username, password) {
    const data = await authApi.login({ username, password })
    token.value = data.token
    user.value = data.user
    localStorage.setItem('pc_token', token.value)
    localStorage.setItem('pc_user', JSON.stringify(user.value))
    return data
  }

  function logout() {
    token.value = ''
    user.value = null
    localStorage.removeItem('pc_token')
    localStorage.removeItem('pc_user')
  }

  return { token, user, isLoggedIn, isAdmin, isDoctor, login, logout }
})