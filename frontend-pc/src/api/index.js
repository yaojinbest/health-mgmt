import http from './http'

// 用户管理
export const usersApi = {
  page: (params) => http.get('/users/page', { params }),
  list: (params) => http.get('/users', { params }),
  save: (data) => http.post('/users/save', data),
  export: (params) => http.get('/users/export', { params, responseType: 'blob' })
}

// 健康数据
export const healthDataApi = {
  page: (params) => http.get('/health-data/list/page', { params }),
  list: (params) => http.get('/health-data/list', { params }),
  save: (data) => http.post('/health-data/save', data),
  export: (params) => http.get('/health-data/export', { params, responseType: 'blob' })
}

// 用药记录
export const medicineApi = {
  page: (params) => http.get('/medicine/list/page', { params }),
  list: (params) => http.get('/medicine/list', { params }),
  save: (data) => http.post('/medicine/save', data),
  finish: (id) => http.post(`/medicine/finish/${id}`),
  export: (params) => http.get('/medicine/export', { params, responseType: 'blob' })
}

// 咨询会话
export const consultationApi = {
  page: (params) => http.get('/consultations/page', { params }),
  list: (params) => http.get('/consultations', { params }),
  export: (params) => http.get('/consultations/export', { params, responseType: 'blob' })
}

// 文章
export const articleApi = {
  page: (params) => http.get('/articles/page', { params }),
  list: (params) => http.get('/articles', { params })
}

// 医院/科室/医生
export const medicalApi = {
  hospitals: (params) => http.get('/medical/hospitals', { params }),
  hospitalsPage: (params) => http.get('/medical/hospitals/page', { params }),
  departments: (params) => http.get('/medical/departments', { params }),
  departmentsPage: (params) => http.get('/medical/departments/page', { params }),
  doctors: (params) => http.get('/medical/doctors', { params }),
  doctorsPage: (params) => http.get('/medical/doctors/page', { params })
}

// Dashboard 统计
export const statsApi = {
  overview: () => http.get('/admin/stats/overview'),
  healthTrends: (days = 7) => http.get('/admin/stats/health-trends', { params: { days } }),
  consultationTrends: (days = 7) => http.get('/admin/stats/consultation-trends', { params: { days } }),
  userDistribution: () => http.get('/admin/stats/user-distribution'),
  warnTop: (limit = 10) => http.get('/admin/stats/warn-top', { params: { limit } })
}

// 认证
export const authApi = {
  login: (data) => http.post('/auth/login', data)
}

// 通用工具: 触发浏览器下载 Blob
export function downloadBlob(blob, filename) {
  const url = window.URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = filename
  document.body.appendChild(a)
  a.click()
  document.body.removeChild(a)
  window.URL.revokeObjectURL(url)
}