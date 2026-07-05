<template>
  <div class="page-container">
    <div class="page-header">
      <h2 class="page-title">用户管理</h2>
      <el-button type="primary" @click="openCreate">
        <el-icon><Plus /></el-icon> 新增用户
      </el-button>
    </div>

    <div class="toolbar">
      <el-input
        v-model="query.keyword"
        placeholder="搜索用户名 / 姓名 / 手机号"
        clearable
        style="width: 240px;"
        @keyup.enter="onSearch"
        @clear="onSearch"
      >
        <template #prefix><el-icon><Search /></el-icon></template>
      </el-input>

      <el-select v-model="query.role" placeholder="角色" clearable style="width: 140px;" @change="onSearch">
        <el-option label="患者" value="USER" />
        <el-option label="医生" value="DOCTOR" />
        <el-option label="管理员" value="ADMIN" />
      </el-select>

      <el-button type="primary" @click="onSearch">
        <el-icon><Search /></el-icon> 查询
      </el-button>
      <el-button @click="onReset">重置</el-button>

      <span class="spacer" />

      <el-button type="success" @click="onExport" :loading="exporting">
        <el-icon><Download /></el-icon> 导出 CSV
      </el-button>
    </div>

    <div class="data-card">
      <el-table :data="list" v-loading="loading" stripe border>
        <el-table-column prop="id" label="ID" width="60" />
        <el-table-column prop="username" label="用户名" width="120" />
        <el-table-column prop="realName" label="真实姓名" width="120" />
        <el-table-column prop="phone" label="手机号" width="140" />
        <el-table-column label="角色" width="100">
          <template #default="{ row }">
            <el-tag :type="roleTagType(row.role)" size="small">
              {{ roleLabel(row.role) }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="gender" label="性别" width="60" />
        <el-table-column prop="age" label="年龄" width="60" />
        <el-table-column label="状态" width="80">
          <template #default="{ row }">
            <el-tag :type="row.status === 'ACTIVE' ? 'success' : 'info'" size="small">
              {{ row.status === 'ACTIVE' ? '启用' : '停用' }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="createTime" label="创建时间" width="160" />
        <el-table-column label="操作" width="180" fixed="right">
          <template #default="{ row }">
            <el-button link type="primary" @click="openEdit(row)">编辑</el-button>
            <el-popconfirm
              :title="`确认删除用户 ${row.username}?`"
              @confirm="onDelete(row)"
            >
              <template #reference>
                <el-button link type="danger">删除</el-button>
              </template>
            </el-popconfirm>
          </template>
        </el-table-column>
        <template #empty>
          <el-empty description="没有数据" />
        </template>
      </el-table>

      <div class="pagination">
        <el-pagination
          v-model:current-page="query.page"
          v-model:page-size="query.size"
          :page-sizes="[10, 20, 50, 100]"
          :total="total"
          layout="total, sizes, prev, pager, next, jumper"
          @size-change="loadList"
          @current-change="loadList"
        />
      </div>
    </div>

    <!-- 新增/编辑 弹窗 -->
    <el-dialog
      v-model="dialogVisible"
      :title="editing ? '编辑用户' : '新增用户'"
      width="500px"
      @closed="onDialogClosed"
    >
      <el-form ref="formRef" :model="form" :rules="formRules" label-width="80px">
        <el-form-item label="用户名" prop="username">
          <el-input v-model="form.username" :disabled="editing" />
        </el-form-item>
        <el-form-item label="真实姓名" prop="realName">
          <el-input v-model="form.realName" />
        </el-form-item>
        <el-form-item label="密码" v-if="!editing" prop="password">
          <el-input v-model="form.password" type="password" show-password />
        </el-form-item>
        <el-form-item label="手机号" prop="phone">
          <el-input v-model="form.phone" />
        </el-form-item>
        <el-form-item label="角色" prop="role">
          <el-select v-model="form.role" placeholder="选择角色" style="width: 100%;">
            <el-option label="患者" value="USER" />
            <el-option label="医生" value="DOCTOR" />
            <el-option label="管理员" value="ADMIN" />
          </el-select>
        </el-form-item>
        <el-form-item label="性别">
          <el-radio-group v-model="form.gender">
            <el-radio value="男">男</el-radio>
            <el-radio value="女">女</el-radio>
          </el-radio-group>
        </el-form-item>
        <el-form-item label="年龄">
          <el-input-number v-model="form.age" :min="0" :max="150" />
        </el-form-item>
        <el-form-item label="状态">
          <el-radio-group v-model="form.status">
            <el-radio value="ACTIVE">启用</el-radio>
            <el-radio value="INACTIVE">停用</el-radio>
          </el-radio-group>
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="dialogVisible = false">取消</el-button>
        <el-button type="primary" @click="onSubmit" :loading="submitting">
          {{ editing ? '保存' : '创建' }}
        </el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup>
import { ref, reactive, onMounted } from 'vue'
import { ElMessage } from 'element-plus'
import { usersApi, downloadBlob } from '@/api'

const list = ref([])
const total = ref(0)
const loading = ref(false)
const submitting = ref(false)
const exporting = ref(false)
const dialogVisible = ref(false)
const editing = ref(false)
const formRef = ref(null)

const query = reactive({
  keyword: '',
  role: '',
  page: 1,
  size: 10
})

const form = reactive({
  id: null,
  username: '',
  password: '',
  realName: '',
  phone: '',
  role: 'USER',
  gender: '男',
  age: 30,
  status: 'ACTIVE'
})

const formRules = {
  username: [{ required: true, message: '请输入用户名', trigger: 'blur' }],
  realName: [{ required: true, message: '请输入真实姓名', trigger: 'blur' }],
  phone: [{ required: true, message: '请输入手机号', trigger: 'blur' }],
  role: [{ required: true, message: '请选择角色', trigger: 'change' }]
}

function roleLabel(role) {
  return { USER: '患者', DOCTOR: '医生', ADMIN: '管理员' }[role] || role
}
function roleTagType(role) {
  return { USER: 'success', DOCTOR: 'warning', ADMIN: 'danger' }[role] || ''
}

async function loadList() {
  loading.value = true
  try {
    const data = await usersApi.page({
      keyword: query.keyword || undefined,
      role: query.role || undefined,
      page: query.page,
      size: query.size
    })
    list.value = data.records || []
    total.value = data.total || 0
  } catch (e) {
    list.value = []
    total.value = 0
  } finally {
    loading.value = false
  }
}

function onSearch() {
  query.page = 1
  loadList()
}

function onReset() {
  query.keyword = ''
  query.role = ''
  query.page = 1
  loadList()
}

async function onExport() {
  exporting.value = true
  try {
    const blob = await usersApi.export({
      keyword: query.keyword || undefined,
      role: query.role || undefined
    })
    downloadBlob(blob, `用户列表_${new Date().toISOString().slice(0, 19).replace(/[:T]/g, '-')}.csv`)
    ElMessage.success('导出成功')
  } finally {
    exporting.value = false
  }
}

function openCreate() {
  editing.value = false
  Object.assign(form, {
    id: null, username: '', password: '', realName: '', phone: '',
    role: 'USER', gender: '男', age: 30, status: 'ACTIVE'
  })
  dialogVisible.value = true
}

function openEdit(row) {
  editing.value = true
  Object.assign(form, row)
  dialogVisible.value = true
}

function onDialogClosed() {
  formRef.value?.resetFields()
}

async function onSubmit() {
  await formRef.value.validate(async (valid) => {
    if (!valid) return
    submitting.value = true
    try {
      await usersApi.save(form)
      ElMessage.success(editing.value ? '保存成功' : '创建成功')
      dialogVisible.value = false
      loadList()
    } finally {
      submitting.value = false
    }
  })
}

async function onDelete(row) {
  // 后端没有 DELETE /api/users/{id}, 用 save 把 status 改成 INACTIVE
  await usersApi.save({ ...row, status: 'INACTIVE' })
  ElMessage.success('已停用')
  loadList()
}

onMounted(loadList)
</script>

<style scoped>
.pagination {
  margin-top: 16px;
  display: flex;
  justify-content: flex-end;
}
</style>