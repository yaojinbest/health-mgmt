<template>
  <div class="page-container">
    <div class="page-header">
      <h2 class="page-title">在线咨询管理</h2>
    </div>

    <div class="toolbar">
      <el-select v-model="query.status" placeholder="状态" clearable style="width: 140px;" @change="loadList">
        <el-option label="进行中" value="OPEN" />
        <el-option label="已关闭" value="CLOSED" />
      </el-select>
      <el-button type="primary" @click="loadList">查询</el-button>
      <span class="spacer" />
      <el-button type="success" @click="onExport">
        <el-icon><Download /></el-icon> 导出 CSV
      </el-button>
    </div>

    <div class="data-card">
      <el-table :data="list" v-loading="loading" stripe border>
        <el-table-column prop="id" label="ID" width="60" />
        <el-table-column prop="userId" label="用户ID" width="80" />
        <el-table-column prop="userName" label="用户姓名" width="120" />
        <el-table-column prop="doctorId" label="医生ID" width="80" />
        <el-table-column prop="doctorName" label="医生" min-width="200" show-overflow-tooltip />
        <el-table-column prop="title" label="咨询标题" min-width="200" show-overflow-tooltip />
        <el-table-column prop="messageCount" label="消息数" width="80" />
        <el-table-column label="状态" width="90">
          <template #default="{ row }">
            <el-tag :type="row.status === 'OPEN' ? 'success' : 'info'" size="small">
              {{ row.status === 'OPEN' ? '进行中' : '已关闭' }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="createTime" label="创建时间" width="160" />
        <el-table-column prop="followUpTime" label="复诊时间" width="160" />
      </el-table>
      <div class="pagination">
        <el-pagination
          v-model:current-page="query.page"
          v-model:page-size="query.size"
          :page-sizes="[10, 20, 50]"
          :total="total"
          layout="total, sizes, prev, pager, next"
          @size-change="loadList"
          @current-change="loadList"
        />
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, reactive, onMounted } from 'vue'
import { ElMessage } from 'element-plus'
import { consultationApi, downloadBlob } from '@/api'

const list = ref([])
const total = ref(0)
const loading = ref(false)

const query = reactive({
  status: '',
  page: 1,
  size: 10
})

async function loadList() {
  loading.value = true
  try {
    const data = await consultationApi.page({
      status: query.status || undefined,
      page: query.page,
      size: query.size
    })
    list.value = data.records || []
    total.value = data.total || 0
  } finally {
    loading.value = false
  }
}

async function onExport() {
  try {
    const blob = await consultationApi.export({
      status: query.status || undefined
    })
    downloadBlob(blob, `咨询会话_${new Date().toISOString().slice(0, 19).replace(/[:T]/g, '-')}.csv`)
    ElMessage.success('导出成功')
  } catch (e) { /* 拦截器处理 */ }
}

onMounted(loadList)
</script>

<style scoped>
.pagination { margin-top: 16px; display: flex; justify-content: flex-end; }
</style>