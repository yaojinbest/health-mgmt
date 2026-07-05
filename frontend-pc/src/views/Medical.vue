<template>
  <div class="page-container">
    <div class="page-header">
      <h2 class="page-title">医疗资源管理</h2>
    </div>

    <el-tabs v-model="activeTab" class="medical-tabs">
      <!-- 医院 Tab -->
      <el-tab-pane label="医院" name="hospitals">
        <div class="toolbar">
          <el-input
            v-model="hospitalQuery.keyword"
            placeholder="搜索医院名称 / 地址"
            clearable
            style="width: 280px;"
            @keyup.enter="loadHospitals"
            @clear="loadHospitals"
          >
            <template #prefix><el-icon><Search /></el-icon></template>
          </el-input>
          <el-button type="primary" @click="loadHospitals">查询</el-button>
          <el-button @click="hospitalQuery.keyword = ''; loadHospitals()">重置</el-button>
          <span class="spacer" />
          <el-button type="primary" @click="openHospitalDialog()">
            <el-icon><Plus /></el-icon> 新增医院
          </el-button>
        </div>
        <div class="data-card">
          <el-table :data="hospitalList" v-loading="hospitalLoading" stripe border>
            <el-table-column prop="id" label="ID" width="60" />
            <el-table-column prop="name" label="医院名称" min-width="180" />
            <el-table-column prop="address" label="地址" min-width="240" show-overflow-tooltip />
            <el-table-column prop="phone" label="电话" width="140" />
            <el-table-column prop="level" label="等级" width="100" />
            <el-table-column prop="description" label="简介" min-width="200" show-overflow-tooltip />
            <el-table-column label="操作" width="160" fixed="right">
              <template #default="{ row }">
                <el-button link type="primary" @click="openHospitalDialog(row)">编辑</el-button>
                <el-button link type="danger" @click="onHospitalDelete(row)">删除</el-button>
              </template>
            </el-table-column>
          </el-table>
          <div class="pagination">
            <el-pagination
              v-model:current-page="hospitalQuery.page"
              v-model:page-size="hospitalQuery.size"
              :page-sizes="[10, 20, 50]"
              :total="hospitalTotal"
              layout="total, sizes, prev, pager, next"
              @size-change="loadHospitals"
              @current-change="loadHospitals"
            />
          </div>
        </div>
      </el-tab-pane>

      <!-- 科室 Tab -->
      <el-tab-pane label="科室" name="departments">
        <div class="toolbar">
          <el-input
            v-model="deptQuery.keyword"
            placeholder="搜索科室名称"
            clearable
            style="width: 200px;"
            @keyup.enter="loadDepartments"
            @clear="loadDepartments"
          >
            <template #prefix><el-icon><Search /></el-icon></template>
          </el-input>
          <el-select
            v-model="deptQuery.hospitalId"
            placeholder="所属医院"
            clearable
            filterable
            style="width: 220px;"
            @change="loadDepartments"
          >
            <el-option v-for="h in hospitalList" :key="h.id" :label="h.name" :value="h.id" />
          </el-select>
          <el-button type="primary" @click="loadDepartments">查询</el-button>
          <span class="spacer" />
          <el-button type="primary" @click="openDeptDialog()">
            <el-icon><Plus /></el-icon> 新增科室
          </el-button>
        </div>
        <div class="data-card">
          <el-table :data="deptList" v-loading="deptLoading" stripe border>
            <el-table-column prop="id" label="ID" width="60" />
            <el-table-column prop="name" label="科室名称" min-width="160" />
            <el-table-column label="所属医院" min-width="180">
              <template #default="{ row }">
                {{ hospitalMap.get(row.hospitalId) || '-' }}
              </template>
            </el-table-column>
            <el-table-column prop="description" label="简介" min-width="240" show-overflow-tooltip />
            <el-table-column label="操作" width="160" fixed="right">
              <template #default="{ row }">
                <el-button link type="primary" @click="openDeptDialog(row)">编辑</el-button>
                <el-button link type="danger" @click="onDeptDelete(row)">删除</el-button>
              </template>
            </el-table-column>
          </el-table>
          <div class="pagination">
            <el-pagination
              v-model:current-page="deptQuery.page"
              v-model:page-size="deptQuery.size"
              :page-sizes="[10, 20, 50]"
              :total="deptTotal"
              layout="total, sizes, prev, pager, next"
              @size-change="loadDepartments"
              @current-change="loadDepartments"
            />
          </div>
        </div>
      </el-tab-pane>

      <!-- 医生 Tab -->
      <el-tab-pane label="医生" name="doctors">
        <div class="toolbar">
          <el-input
            v-model="doctorQuery.keyword"
            placeholder="搜索职称 / 专长"
            clearable
            style="width: 200px;"
            @keyup.enter="loadDoctors"
            @clear="loadDoctors"
          >
            <template #prefix><el-icon><Search /></el-icon></template>
          </el-input>
          <el-select
            v-model="doctorQuery.hospitalId"
            placeholder="医院"
            clearable
            filterable
            style="width: 200px;"
            @change="loadDoctors"
          >
            <el-option v-for="h in hospitalList" :key="h.id" :label="h.name" :value="h.id" />
          </el-select>
          <el-select
            v-model="doctorQuery.departmentId"
            placeholder="科室"
            clearable
            filterable
            style="width: 200px;"
            @change="loadDoctors"
          >
            <el-option v-for="d in deptList" :key="d.id" :label="d.name" :value="d.id" />
          </el-select>
          <el-button type="primary" @click="loadDoctors">查询</el-button>
          <span class="spacer" />
          <el-button type="success" @click="onDoctorExport">
            <el-icon><Download /></el-icon> 导出 CSV
          </el-button>
        </div>
        <div class="data-card">
          <el-table :data="doctorList" v-loading="doctorLoading" stripe border>
            <el-table-column prop="id" label="ID" width="60" />
            <el-table-column prop="doctorName" label="医生姓名" width="120" />
            <el-table-column prop="title" label="职称" width="140" />
            <el-table-column prop="specialty" label="专长" min-width="200" show-overflow-tooltip />
            <el-table-column prop="hospitalName" label="医院" width="160" show-overflow-tooltip />
            <el-table-column prop="departmentName" label="科室" width="120" />
            <el-table-column label="状态" width="80">
              <template #default="{ row }">
                <el-tag :type="row.status === 'ACTIVE' ? 'success' : 'info'" size="small">
                  {{ row.status === 'ACTIVE' ? '在岗' : '停诊' }}
                </el-tag>
              </template>
            </el-table-column>
            <el-table-column prop="profile" label="简介" min-width="200" show-overflow-tooltip />
          </el-table>
          <div class="pagination">
            <el-pagination
              v-model:current-page="doctorQuery.page"
              v-model:page-size="doctorQuery.size"
              :page-sizes="[10, 20, 50]"
              :total="doctorTotal"
              layout="total, sizes, prev, pager, next"
              @size-change="loadDoctors"
              @current-change="loadDoctors"
            />
          </div>
        </div>
      </el-tab-pane>
    </el-tabs>

    <!-- 医院 弹窗 -->
    <el-dialog v-model="hospitalDialogVisible" :title="hospitalForm.id ? '编辑医院' : '新增医院'" width="500px">
      <el-form ref="hospitalFormRef" :model="hospitalForm" :rules="hospitalRules" label-width="80px">
        <el-form-item label="名称" prop="name">
          <el-input v-model="hospitalForm.name" />
        </el-form-item>
        <el-form-item label="地址">
          <el-input v-model="hospitalForm.address" />
        </el-form-item>
        <el-form-item label="电话">
          <el-input v-model="hospitalForm.phone" />
        </el-form-item>
        <el-form-item label="等级">
          <el-select v-model="hospitalForm.level" placeholder="选择等级" clearable>
            <el-option label="三级甲等" value="三级甲等" />
            <el-option label="三级乙等" value="三级乙等" />
            <el-option label="二级甲等" value="二级甲等" />
            <el-option label="二级乙等" value="二级乙等" />
            <el-option label="一级" value="一级" />
          </el-select>
        </el-form-item>
        <el-form-item label="简介">
          <el-input v-model="hospitalForm.description" type="textarea" :rows="3" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="hospitalDialogVisible = false">取消</el-button>
        <el-button type="primary" @click="onHospitalSubmit" :loading="submitting">保存</el-button>
      </template>
    </el-dialog>

    <!-- 科室 弹窗 -->
    <el-dialog v-model="deptDialogVisible" :title="deptForm.id ? '编辑科室' : '新增科室'" width="500px">
      <el-form ref="deptFormRef" :model="deptForm" :rules="deptRules" label-width="80px">
        <el-form-item label="名称" prop="name">
          <el-input v-model="deptForm.name" />
        </el-form-item>
        <el-form-item label="所属医院" prop="hospitalId">
          <el-select v-model="deptForm.hospitalId" placeholder="选择医院" filterable style="width: 100%;">
            <el-option v-for="h in hospitalList" :key="h.id" :label="h.name" :value="h.id" />
          </el-select>
        </el-form-item>
        <el-form-item label="简介">
          <el-input v-model="deptForm.description" type="textarea" :rows="3" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="deptDialogVisible = false">取消</el-button>
        <el-button type="primary" @click="onDeptSubmit" :loading="submitting">保存</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup>
import { ref, reactive, computed, onMounted } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { medicalApi, downloadBlob } from '@/api'

const activeTab = ref('hospitals')

// 医院
const hospitalList = ref([])
const hospitalTotal = ref(0)
const hospitalLoading = ref(false)
const hospitalDialogVisible = ref(false)
const hospitalFormRef = ref(null)
const hospitalForm = reactive({ id: null, name: '', address: '', phone: '', level: '', description: '' })
const hospitalRules = {
  name: [{ required: true, message: '请输入名称', trigger: 'blur' }]
}
const hospitalQuery = reactive({ keyword: '', page: 1, size: 10 })

// 科室
const deptList = ref([])
const deptTotal = ref(0)
const deptLoading = ref(false)
const deptDialogVisible = ref(false)
const deptFormRef = ref(null)
const deptForm = reactive({ id: null, name: '', hospitalId: null, description: '' })
const deptRules = {
  name: [{ required: true, message: '请输入名称', trigger: 'blur' }],
  hospitalId: [{ required: true, message: '请选择医院', trigger: 'change' }]
}
const deptQuery = reactive({ keyword: '', hospitalId: null, page: 1, size: 10 })

// 医生
const doctorList = ref([])
const doctorTotal = ref(0)
const doctorLoading = ref(false)
const doctorQuery = reactive({ keyword: '', hospitalId: null, departmentId: null, page: 1, size: 10 })

const submitting = ref(false)

// hospitalMap 供科室/医生 tab 用
const hospitalMap = computed(() => {
  const m = new Map()
  hospitalList.value.forEach(h => m.set(h.id, h.name))
  return m
})

async function loadHospitals() {
  hospitalLoading.value = true
  try {
    const data = await medicalApi.hospitalsPage({
      keyword: hospitalQuery.keyword || undefined,
      page: hospitalQuery.page,
      size: hospitalQuery.size
    })
    hospitalList.value = data.records || []
    hospitalTotal.value = data.total || 0
  } finally {
    hospitalLoading.value = false
  }
}

async function loadDepartments() {
  deptLoading.value = true
  try {
    const data = await medicalApi.departmentsPage({
      keyword: deptQuery.keyword || undefined,
      hospitalId: deptQuery.hospitalId || undefined,
      page: deptQuery.page,
      size: deptQuery.size
    })
    deptList.value = data.records || []
    deptTotal.value = data.total || 0
  } finally {
    deptLoading.value = false
  }
}

async function loadDoctors() {
  doctorLoading.value = true
  try {
    const data = await medicalApi.doctorsPage({
      keyword: doctorQuery.keyword || undefined,
      hospitalId: doctorQuery.hospitalId || undefined,
      departmentId: doctorQuery.departmentId || undefined,
      page: doctorQuery.page,
      size: doctorQuery.size
    })
    doctorList.value = data.records || []
    doctorTotal.value = data.total || 0
  } finally {
    doctorLoading.value = false
  }
}

async function onDoctorExport() {
  try {
    const res = await medicalApi.doctorsPage({
      keyword: doctorQuery.keyword || undefined,
      hospitalId: doctorQuery.hospitalId || undefined,
      departmentId: doctorQuery.departmentId || undefined,
      page: 1,
      size: 10000  // 全量导出
    })
    const headers = ['ID', '医生姓名', '职称', '专长', '医院', '科室', '状态']
    const rows = res.records || []
    const csv = [headers.join(','), ...rows.map(r =>
      [r.id, r.doctorName, r.title, r.specialty, r.hospitalName, r.departmentName, r.status]
        .map(c => /[,"\r\n]/.test(String(c)) ? `"${String(c).replace(/"/g, '""')}"` : c)
        .join(',')
    )].join('\r\n')
    const blob = new Blob(['\uFEFF' + csv], { type: 'text/csv;charset=utf-8' })
    downloadBlob(blob, `医生列表_${new Date().toISOString().slice(0, 19).replace(/[:T]/g, '-')}.csv`)
    ElMessage.success('导出成功')
  } catch (e) { /* 拦截器已处理 */ }
}

function openHospitalDialog(row) {
  Object.assign(hospitalForm, row || { id: null, name: '', address: '', phone: '', level: '', description: '' })
  hospitalDialogVisible.value = true
}
function openDeptDialog(row) {
  Object.assign(deptForm, row || { id: null, name: '', hospitalId: null, description: '' })
  deptDialogVisible.value = true
}

async function onHospitalSubmit() {
  await hospitalFormRef.value.validate(async (valid) => {
    if (!valid) return
    submitting.value = true
    try {
      await medicalApi.hospitalsPage  // 触发一个无关的 import 防止 tree-shake 误删?
      // 后端没 /api/medical/hospitals/save 通用接口, 这里略 (演示项目无此接口)
      ElMessage.warning('演示项目暂未提供新增/编辑医院 API, 仅展示列表')
      hospitalDialogVisible.value = false
    } finally {
      submitting.value = false
    }
  })
}

async function onHospitalDelete(row) {
  await ElMessageBox.confirm(`确认删除医院 "${row.name}"?`, '警告', { type: 'warning' })
  ElMessage.warning('演示项目暂未提供删除 API')
}

async function onDeptSubmit() {
  await deptFormRef.value.validate(async (valid) => {
    if (!valid) return
    ElMessage.warning('演示项目暂未提供新增/编辑科室 API')
    deptDialogVisible.value = false
  })
}

async function onDeptDelete(row) {
  await ElMessageBox.confirm(`确认删除科室 "${row.name}"?`, '警告', { type: 'warning' })
  ElMessage.warning('演示项目暂未提供删除 API')
}

onMounted(async () => {
  await loadHospitals()
  await loadDepartments()
  await loadDoctors()
})
</script>

<style scoped>
.medical-tabs {
  background: white;
  border-radius: 8px;
  padding: 16px;
}
.pagination {
  margin-top: 16px;
  display: flex;
  justify-content: flex-end;
}
</style>