<template>
  <div class="page-container">
    <div class="page-header">
      <h2 class="page-title">用药管理</h2>
    </div>

    <div class="toolbar">
      <el-input
        v-model="query.keyword"
        placeholder="搜索药品名 / 剂量"
        clearable
        style="width: 240px;"
        @keyup.enter="loadList"
        @clear="loadList"
      >
        <template #prefix><el-icon><Search /></el-icon></template>
      </el-input>
      <el-select v-model="query.status" placeholder="状态" clearable style="width: 140px;" @change="loadList">
        <el-option label="进行中" value="ACTIVE" />
        <el-option label="已结束" value="FINISHED" />
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
        <el-table-column prop="medicineName" label="药品名称" min-width="160" />
        <el-table-column prop="usageMethod" label="用法" min-width="140" show-overflow-tooltip />
        <el-table-column prop="dosage" label="剂量" min-width="140" show-overflow-tooltip />
        <el-table-column prop="reminderTimes" label="提醒时间" width="120" />
        <el-table-column prop="startDate" label="开始日期" width="110" />
        <el-table-column prop="endDate" label="结束日期" width="110" />
        <el-table-column label="状态" width="90">
          <template #default="{ row }">
            <el-tag :type="row.status === 'ACTIVE' ? 'success' : 'info'" size="small">
              {{ row.status === 'ACTIVE' ? '进行中' : '已结束' }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="warning" label="注意事项" min-width="200" show-overflow-tooltip />
        <el-table-column prop="createTime" label="创建时间" width="160" />
        <el-table-column label="操作" width="100" fixed="right">
          <template #default="{ row }">
            <el-popconfirm
              v-if="row.status === 'ACTIVE'"
              :title="`确认结束用药 ${row.medicineName}?`"
              @confirm="onFinish(row)"
            >
              <template #reference>
                <el-button link type="warning">结束</el-button>
              </template>
            </el-popconfirm>
          </template>
        </el-table-column>
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
import { medicineApi, downloadBlob } from '@/api'

const list = ref([])
const total = ref(0)
const loading = ref(false)

const query = reactive({
  keyword: '',
  status: '',
  page: 1,
  size: 10
})

async function loadList() {
  loading.value = true
  try {
    const data = await medicineApi.page({
      keyword: query.keyword || undefined,
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
    const blob = await medicineApi.export({
      status: query.status || undefined
    })
    downloadBlob(blob, `用药记录_${new Date().toISOString().slice(0, 19).replace(/[:T]/g, '-')}.csv`)
    ElMessage.success('导出成功')
  } catch (e) { /* 拦截器处理 */ }
}

async function onFinish(row) {
  try {
    await medicineApi.finish(row.id)
    ElMessage.success('已结束')
    loadList()
  } catch (e) { /* 拦截器处理 */ }
}

onMounted(loadList)
</script>

<style scoped>
.pagination { margin-top: 16px; display: flex; justify-content: flex-end; }
</style>