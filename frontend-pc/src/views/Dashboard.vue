<template>
  <div class="page-container">
    <div class="page-header">
      <h2 class="page-title">系统概览</h2>
      <el-button type="primary" @click="loadAll" :loading="loading">
        <el-icon><Refresh /></el-icon> 刷新
      </el-button>
    </div>

    <div class="metric-grid">
      <div class="metric-card">
        <div class="metric-label">用户总数</div>
        <div class="metric-value primary">{{ overview.totalUsers ?? '-' }}</div>
        <div class="metric-extra">
          患者 {{ overview.totalPatients ?? 0 }} ·
          医生 {{ overview.totalDoctors ?? 0 }} ·
          管理员 {{ overview.adminCount ?? 0 }}
        </div>
      </div>
      <div class="metric-card">
        <div class="metric-label">健康数据</div>
        <div class="metric-value success">{{ overview.totalHealthRecords ?? '-' }}</div>
        <div class="metric-extra">
          警告数据 {{ overview.warnHealthRecords ?? 0 }} 条
        </div>
      </div>
      <div class="metric-card">
        <div class="metric-label">用药记录</div>
        <div class="metric-value warning">{{ overview.totalMedicines ?? '-' }}</div>
        <div class="metric-extra">
          进行中 {{ overview.activeMedicines ?? 0 }} 条
        </div>
      </div>
      <div class="metric-card">
        <div class="metric-label">咨询会话</div>
        <div class="metric-value danger">{{ overview.totalConsultations ?? '-' }}</div>
        <div class="metric-extra">
          待处理 {{ overview.activeConsultations ?? 0 }} 条
        </div>
      </div>
    </div>

    <el-row :gutter="16" style="margin-bottom: 16px;">
      <el-col :span="16">
        <div class="data-card">
          <h3>健康趋势 (近 7 天)</h3>
          <div ref="healthChartRef" style="height: 320px;"></div>
        </div>
      </el-col>
      <el-col :span="8">
        <div class="data-card">
          <h3>用户分布</h3>
          <div ref="userChartRef" style="height: 320px;"></div>
        </div>
      </el-col>
    </el-row>

    <el-row :gutter="16">
      <el-col :span="14">
        <div class="data-card">
          <h3>咨询趋势 (近 7 天)</h3>
          <div ref="consultChartRef" style="height: 280px;"></div>
        </div>
      </el-col>
      <el-col :span="10">
        <div class="data-card">
          <h3>警告 Top 5</h3>
          <el-table :data="warnTop" size="small">
            <el-table-column prop="rank" label="排名" width="60" />
            <el-table-column prop="userName" label="用户" />
            <el-table-column prop="warnCount" label="警告次数" width="100">
              <template #default="{ row }">
                <el-tag type="warning">{{ row.warnCount }}</el-tag>
              </template>
            </el-table-column>
          </el-table>
        </div>
      </el-col>
    </el-row>
  </div>
</template>

<script setup>
import { ref, onMounted, onUnmounted, nextTick } from 'vue'
import * as echarts from 'echarts'
import { statsApi } from '@/api'

const loading = ref(false)
const overview = ref({})
const warnTop = ref([])
const healthChartRef = ref(null)
const userChartRef = ref(null)
const consultChartRef = ref(null)
let healthChart, userChart, consultChart

async function loadAll() {
  loading.value = true
  try {
    const [ov, ht, ct, ud, wt] = await Promise.all([
      statsApi.overview(),
      statsApi.healthTrends(7),
      statsApi.consultationTrends(7),
      statsApi.userDistribution(),
      statsApi.warnTop(5)
    ])
    overview.value = ov
    warnTop.value = wt || []
    await nextTick()
    renderHealthChart(ht)
    renderUserChart(ud)
    renderConsultChart(ct)
  } finally {
    loading.value = false
  }
}

function renderHealthChart(data) {
  if (!healthChartRef.value) return
  healthChart = healthChart?.dispose() || healthChart
  healthChart = echarts.init(healthChartRef.value)
  healthChart.setOption({
    tooltip: { trigger: 'axis' },
    legend: { data: ['收缩压', '舒张压', '心率', '警告次数'] },
    grid: { left: 40, right: 30, top: 40, bottom: 30 },
    xAxis: { type: 'category', data: data.dates },
    yAxis: [
      { type: 'value', name: '指标' },
      { type: 'value', name: '警告', position: 'right' }
    ],
    series: [
      { name: '收缩压', type: 'line', data: data.systolic, smooth: true, connectNulls: true },
      { name: '舒张压', type: 'line', data: data.diastolic, smooth: true, connectNulls: true },
      { name: '心率', type: 'line', data: data.heartRate, smooth: true, connectNulls: true },
      { name: '警告次数', type: 'bar', yAxisIndex: 1, data: data.warnCount, itemStyle: { color: '#E6A23C' } }
    ]
  })
}

function renderUserChart(data) {
  if (!userChartRef.value) return
  userChart = userChart?.dispose() || userChart
  userChart = echarts.init(userChartRef.value)
  userChart.setOption({
    tooltip: { trigger: 'item' },
    legend: { bottom: 0 },
    series: [{
      type: 'pie',
      radius: ['40%', '70%'],
      data: data.map(d => ({ name: d.label, value: d.count }))
    }]
  })
}

function renderConsultChart(data) {
  if (!consultChartRef.value) return
  consultChart = consultChart?.dispose() || consultChart
  consultChart = echarts.init(consultChartRef.value)
  consultChart.setOption({
    tooltip: { trigger: 'axis' },
    legend: { data: ['新建', '关闭'] },
    grid: { left: 40, right: 20, top: 40, bottom: 30 },
    xAxis: { type: 'category', data: data.dates },
    yAxis: { type: 'value' },
    series: [
      { name: '新建', type: 'bar', data: data.created, itemStyle: { color: '#409EFF' } },
      { name: '关闭', type: 'bar', data: data.closed, itemStyle: { color: '#67C23A' } }
    ]
  })
}

function onResize() {
  healthChart?.resize()
  userChart?.resize()
  consultChart?.resize()
}

onMounted(() => {
  loadAll()
  window.addEventListener('resize', onResize)
})

onUnmounted(() => {
  window.removeEventListener('resize', onResize)
  healthChart?.dispose()
  userChart?.dispose()
  consultChart?.dispose()
})
</script>

<style scoped>
h3 {
  margin: 0 0 12px 0;
  font-size: 15px;
  font-weight: 600;
  color: var(--text-primary);
}
</style>