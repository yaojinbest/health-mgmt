import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

export default defineConfig({
  plugins: [vue()],
  server: {
    port: 5176,
    proxy: {
      '/api': 'http://localhost:8090',
      '/uploads': 'http://localhost:8090'
    }
  }
})
