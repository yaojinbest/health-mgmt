<template>
  <div class="page-container">
    <div class="page-header">
      <h2 class="page-title">健康数据管理</h2>
    </div>

    <div class="metric-grid">
      <div class="metric-card">
        <div class="metric-label">数据总条数</div>
        <div class="metric-value primary">{{ total }}</div>
      </div>
      <div class="metric-card">
        <div class="metric-label">警告条数</div>
        <div class="metric-value danger">{{ warnCount }}</div>
      </div>
      <div class="metric-card">
        <div class="metric-label">平均收缩压</div>
        <div class="metric-value">{{ avgSystolic ?? '-' }}</div>
        <div class="metric-extra">mmHg</div>
      </div>
      <div class="metric-card">
        <div class="metric-label">平均心率</div>
        <div class="metric-value">{{ avgHeartRate ?? '-' }}</div>
        <div class="metric-extra">bpm</div>
      </div>
    </div>

    <el-row :gutter="16" style="margin-bottom: 16px;">
      <el-col :span="16">
        <div class="data-card">
          <h3>趋势图 (近 30 天, 平均值)</h3>
          <div ref="trendChartRef" style="height: 300px;"></div>
        </div>
      </el-col>
      <el-col :span="8">
        <div class="data-card">
          <h3>警告分布</h3>
          <div ref="warnChartRef" style="height: 300px;"></div>
        </div>
      </el-col>
    </el-row>

    <div class="toolbar">
      <el-input
        v-model="query.userId"
        placeholder="用户ID (留空看全部)"
        clearable
        style="width: 180px;"
        @keyup.enter="loadList"
        @clear="loadList"
      >
        <template #prefix><el-icon><User /></el-icon></template>
      </el-input>
      <el-select v-model="query.warningLevel" placeholder="警告级别" clearable style="width: 140px;" @change="loadList">
        <el-option label="警告" value="WARN" />
        <el-option label="正常" value="NORMAL" />
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
        <el-table-column prop="systolic" label="收缩压" width="80" />
        <el-table-column prop="diastolic" label="舒张压" width="80" />
        <el-table-column prop="bloodSugar" label="血糖" width="80" />
        <el-table-column prop="heartRate" label="心率" width="80" />
        <el-table-column prop="steps" label="步数" width="80" />
        <el-table-column prop="sleepHours" label="睡眠(h)" width="80" />
        <el-table-column prop="weight" label="体重(kg)" width="80" />
        <el-table-column label="警告级别" width="100">
          <template #default="{ row }">
            <el-tag :type="row.warningLevel === 'WARN' ? 'danger' : 'success'" size="small">
              {{ row.warningLevel === 'WARN' ? '警告' : '正常' }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="warningMessage" label="警告信息" min-width="180" show-overflow-tooltip />
        <el-table-column prop="recordTime" label="记录时间" width="160" />
      </el-table>
      <div class="pagination">
        <el-pagination
          v-model:current-page="query.page"
          v-model:page-size="query.size"
          :page-sizes="[10, 20, 50]"
          :total="total"
          layout="total, sizes, prev, pager, next, jumper"
          @size-change="loadList"
          @current-change="loadList"
        />
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, reactive, computed, onMounted, onUnmounted, nextTick } from 'vue'
import { ElMessage } from 'element-plus'
import * as echarts from 'echarts'
import { healthDataApi, statsApi, downloadBlob } from '@/api'

const list = ref([])
const total = ref(0)
const loading = ref(false)

const query = reactive({
  userId: '',
  warningLevel: '',
  page: 1,
  size: 10
})

const warnCount = computed(() => list.value.filter(r => r.warningLevel === 'WARN').length)
const avgSystolic = computed(() => {
  const arr = list.value.map(r => r.systolic).filter(v => v != null)
  if (!arr.length) return null
  return Math.round(arr.reduce((a, b) => a + b, 0) / arr.length)
})
const avgHeartRate = computed(() => {
  const arr = list.value.map(r => r.heartRate).filter(v => v != null)
  if (!arr.length) return null
  return Math.round(arr.reduce((a, b) => a + b, 0) / arr.length)
})

const trendChartRef = ref(null)
const warnChartRef = ref(null)
let trendChart, warnChart

async function loadList() {
  loading.value = true
  try {
    const data = await healthDataApi.page({
      userId: query.userId || undefined,
      warningLevel: query.warningLevel || undefined,
      page: query.page,
      size: query.size
    })
    list.value = data.records || []
    total.value = data.total || 0
  } finally {
    loading.value = false
  }
}

async function loadCharts() {
  const [trend] = await Promise.all([
    statsApi.healthTrends(30)
  ])
  await nextTick()
  renderTrendChart(trend)
  renderWarnChart()
}

function renderTrendChart(data) {
  if (!trendChartRef.value) return
  trendChart = trendChart?.dispose() || trendChart
  trendChart = echarts.init(trendChartRef.value)
  trendChart.setOption({
    tooltip: { trigger: 'axis' },
    legend: { data: ['收缩压', '舒张压', '心率', '警告'] },
    grid: { left: 40, right: 30, top: 40, bottom: 30 },
    xAxis: { type: 'category', data: data.dates, axisLabel: { rotate: 30 } },
    yAxis: [
      { type: 'value', name: '血压/心率' },
      { type: 'value', name: '警告', position: 'right' }
    ],
    series: [
      { name: '收缩压', type: 'line', data: data.systolic, smooth: true, connectNulls: true, itemStyle: { color: '#F56C6C' } },
      { name: '舒张压', type: 'line', data: data.diastolic, smooth: true, connectNulls: true, itemStyle: { color: '#E6A23C' } },
      { name: '心率', type: 'line', data: data.heartRate, smooth: true, connectNulls: true, itemStyle: { color: '#67C23A' } },
      { name: '警告', type: 'bar', yAxisIndex: 1, data: data.warnCount, itemStyle: { color: '#909399' } }
    ]
  })
}

function renderWarnChart() {
  if (!warnChartRef.value) return
  warnChart = warnChart?.dispose() || warnChart
  warnChart = echarts.init(warnChartRef.value)
  const warnItems = list.value.filter(r => r.warningLevel === 'WARN')
  warnChart.setOption({
    tooltip: { trigger: 'item' },
    series: [{
      type: 'pie',
      radius: ['40%', '70%'],
      label: { formatter: '{b}: {c}' },
      data: [
        { name: '警告', value: warnItems.length, itemStyle: { color: '#F56C6C' } },
        { name: '正常', value: list.value.length - warnItems.length, itemStyle: { color: '#67C23A' } }
      ]
    }]
  })
}

async function onExport() {
  try {
    const blob = await healthDataApi.export({
      userId: query.userId || undefined
    })
    downloadBlob(blob, `健康数据_${new Date().toISOString().slice(0, 19).replace(/[:T]/g, '-')}.csv`)
    ElMessage.success('导出成功')
  } catch (e) { /* 拦截器处理 */ }
}

function onResize() {
  trendChart?.resize()
  warnChart?.resize()
}

onMounted(() => {
  loadList()
  loadCharts()
  window.addEventListener('resize', onResize)
})
onUnmounted(() => {
  window.removeEventListener('resize', onResize)
  trendChart?.dispose()
  warnChart?.dispose()
})
</script>

<style scoped>
h3 { margin: 0 0 12px 0; font-size: 15px; font-weight: 600; }
.pagination { margin-top: 16px; display: flex; justify-content: flex-end; }
</style>