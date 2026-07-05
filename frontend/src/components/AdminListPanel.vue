<template>
  <section class="adm-list">
    <header class="adm-list-head">
      <div>
        <h2>{{ title }}</h2>
        <p v-if="subtitle">{{ subtitle }}</p>
      </div>
      <span class="adm-list-stat">共 {{ total }} 条 · 当前 {{ rangeStart }}-{{ rangeEnd }} 条</span>
    </header>
    <div class="adm-list-toolbar">
      <div v-if="searchable" class="adm-search">
        <input v-model="keyword" placeholder="搜索关键词..." />
      </div>
      <div v-if="statusTabs.length" class="adm-status-tabs">
        <button
          v-for="tab in statusTabs"
          :key="tab.key"
          type="button"
          class="adm-status-tab"
          :class="{ active: activeStatus === tab.key }"
          @click="activeStatus = tab.key"
        >
          {{ tab.label }}
        </button>
      </div>
      <slot name="toolbar" />
    </div>
    <div v-if="loading" class="adm-loading">
      <span class="adm-loading-bar" />
      <p>数据加载中...</p>
    </div>
    <div v-else-if="isFilteredEmpty" class="adm-empty">
      <span class="adm-empty-icon">🔍</span>
      <strong>{{ emptyFilteredText }}</strong>
      <p>{{ emptyFilteredHint }}</p>
    </div>
    <div v-else-if="!total" class="adm-empty">
      <span class="adm-empty-icon">📭</span>
      <strong>{{ emptyText }}</strong>
      <p>{{ emptyHint }}</p>
    </div>
    <template v-else>
      <div class="adm-table-wrap">
        <table class="adm-table">
          <thead>
            <tr>
              <th class="adm-col-main">{{ label(displayPrimaryField) }}</th>
              <th v-for="field in displayFields" :key="field">{{ label(field) }}</th>
              <th v-if="$slots.actions" class="adm-col-actions">操作</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="item in paginatedItems" :key="item.id">
              <td class="adm-col-main">
                <div class="adm-row-main">
                  <span class="adm-row-avatar">{{ avatarText(item) }}</span>
                  <div>
                    <strong>{{ cellValue(item, displayPrimaryField) }}</strong>
                    <small v-if="item.id">ID {{ item.id }}</small>
                  </div>
                </div>
              </td>
              <td v-for="field in displayFields" :key="field">
                <span v-if="isBadge(field)" class="adm-badge" :class="'tone-' + badgeTone(item, field)">{{ cellValue(item, field) }}</span>
                <span v-else class="adm-cell-text">{{ cellValue(item, field) }}</span>
              </td>
              <td v-if="$slots.actions" class="adm-col-actions">
                <slot name="actions" :item="item" />
              </td>
            </tr>
          </tbody>
        </table>
      </div>
      <PaginationBar
        :page="page"
        :page-size="pageSize"
        :total="total"
        :total-pages="totalPages"
        :range-start="rangeStart"
        :range-end="rangeEnd"
        :page-size-options="pageSizeOptions"
        @update:page="goPage"
        @update:page-size="setPageSize"
      />
    </template>
  </section>
</template>

<script setup>
import { computed, ref, watch } from 'vue'
import PaginationBar from './PaginationBar.vue'
import { usePagination } from '../composables/usePagination'

const props = defineProps({
  title: String,
  subtitle: String,
  items: Array,
  fields: Array,
  labels: Object,
  badgeFields: { type: Array, default: () => ['status', 'statusText'] },
  statusField: { type: String, default: '' },
  statusTabs: { type: Array, default: () => [] },
  primaryField: { type: String, default: '' },
  emptyText: { type: String, default: '暂无数据' },
  emptyHint: { type: String, default: '当前没有可展示的记录' },
  emptyFilteredText: { type: String, default: '无匹配结果' },
  emptyFilteredHint: { type: String, default: '请调整搜索关键词或状态筛选' },
  loading: { type: Boolean, default: false },
  searchable: { type: Boolean, default: true },
  pageSize: { type: Number, default: 10 }
})

const keyword = ref('')
const activeStatus = ref('ALL')

const statusBadgeMap = {
  CONFIRMED: 'success',
  FINISHED: 'neutral',
  CANCELLED: 'muted',
  ACTIVE: 'success',
  OPEN: 'success',
  CLOSED: 'neutral',
  PROCESSING: 'warning',
  INACTIVE: 'danger',
  已确认: 'success',
  已完成: 'neutral',
  已取消: 'muted',
  进行中: 'success',
  处理中: 'warning',
  在职: 'success',
  停诊: 'danger'
}

const displayPrimaryField = computed(() => props.primaryField || props.fields?.[0] || '')

const displayFields = computed(() => {
  const fields = Array.isArray(props.fields) ? props.fields : []
  const primary = displayPrimaryField.value
  return fields.filter(field => field !== primary)
})

const sourceTotal = computed(() => (props.items || []).length)

const isFilteredEmpty = computed(() => sourceTotal.value > 0 && filteredItems.value.length === 0)

const filteredItems = computed(() => {
  let list = props.items || []
  const fields = Array.isArray(props.fields) ? props.fields : []
  if (props.statusField && activeStatus.value !== 'ALL') {
    list = list.filter(item => item[props.statusField] === activeStatus.value)
  }
  const kw = keyword.value.trim().toLowerCase()
  if (props.searchable && kw && fields.length) {
    const searchFields = [...fields, props.primaryField, props.statusField, 'statusText'].filter(Boolean)
    list = list.filter(item => searchFields.some(field => String(item[field] ?? '').toLowerCase().includes(kw)))
  }
  return list
})

const {
  page,
  pageSize,
  pageSizeOptions,
  total,
  totalPages,
  paginatedItems,
  rangeStart,
  rangeEnd,
  goPage,
  resetPage
} = usePagination(filteredItems, { pageSize: props.pageSize })

watch([keyword, activeStatus], resetPage)

function setPageSize(value) {
  pageSize.value = value
}

function label(field) {
  return props.labels?.[field] || field
}

function isBadge(field) {
  return props.badgeFields.includes(field)
}

function cellValue(item, field) {
  if (field === props.statusField && item.statusText) return item.statusText
  const value = item[field]
  return value === null || value === undefined || value === '' ? '-' : value
}

function badgeTone(item, field) {
  const raw = item[field]
  const code = item[props.statusField] || raw
  return statusBadgeMap[code] || statusBadgeMap[raw] || 'neutral'
}

function avatarText(item) {
  return String(item[displayPrimaryField.value] ?? '?').slice(0, 1)
}
</script>
