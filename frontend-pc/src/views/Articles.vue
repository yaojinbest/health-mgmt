<template>
  <div class="page-container">
    <div class="page-header">
      <h2 class="page-title">健康文章</h2>
    </div>

    <div class="toolbar">
      <el-input
        v-model="query.keyword"
        placeholder="搜索标题 / 摘要"
        clearable
        style="width: 240px;"
        @keyup.enter="loadList"
        @clear="loadList"
      >
        <template #prefix><el-icon><Search /></el-icon></template>
      </el-input>
      <el-select v-model="query.category" placeholder="分类" clearable style="width: 140px;" @change="loadList">
        <el-option label="慢病" value="慢病" />
        <el-option label="养生" value="养生" />
        <el-option label="母婴" value="母婴" />
        <el-option label="营养" value="营养" />
        <el-option label="运动" value="运动" />
        <el-option label="心理" value="心理" />
      </el-select>
      <el-input
        v-model="query.diseaseTag"
        placeholder="疾病标签"
        clearable
        style="width: 160px;"
        @keyup.enter="loadList"
        @clear="loadList"
      />
      <el-button type="primary" @click="loadList">查询</el-button>
    </div>

    <div class="data-card">
      <el-table :data="list" v-loading="loading" stripe border>
        <el-table-column prop="id" label="ID" width="60" />
        <el-table-column prop="title" label="标题" min-width="240" show-overflow-tooltip />
        <el-table-column prop="category" label="分类" width="100" />
        <el-table-column prop="diseaseTag" label="疾病标签" width="120" />
        <el-table-column prop="author" label="作者" width="120" />
        <el-table-column prop="viewCount" label="阅读" width="80" />
        <el-table-column prop="summary" label="摘要" min-width="280" show-overflow-tooltip />
        <el-table-column prop="publishTime" label="发布时间" width="160" />
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
import { articleApi } from '@/api'

const list = ref([])
const total = ref(0)
const loading = ref(false)

const query = reactive({
  keyword: '',
  category: '',
  diseaseTag: '',
  page: 1,
  size: 10
})

async function loadList() {
  loading.value = true
  try {
    const data = await articleApi.page({
      keyword: query.keyword || undefined,
      category: query.category || undefined,
      diseaseTag: query.diseaseTag || undefined,
      page: query.page,
      size: query.size
    })
    list.value = data.records || []
    total.value = data.total || 0
  } finally {
    loading.value = false
  }
}

onMounted(loadList)
</script>

<style scoped>
.pagination { margin-top: 16px; display: flex; justify-content: flex-end; }
</style>