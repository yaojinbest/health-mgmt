<template>
  <div class="panel wb-list-panel" :class="{ 'm-card': mobile }">
    <div class="wb-list-head">
      <h2>{{ title }}</h2>
      <span v-if="total" class="wb-list-count">共 {{ total }} 条</span>
    </div>
    <div v-if="!total" class="wb-empty">暂无数据</div>
    <template v-else>
      <div v-if="mobile" class="m-record-list">
        <div v-for="item in paginatedItems" :key="item.id" class="m-record-card">
          <div v-for="field in fields" :key="field" class="m-record-line">
            <span class="m-record-label">{{ label(field) }}</span>
            <span class="m-record-value" :class="{ warn: field === 'warningMessage' && item.warningLevel === 'WARN' }">{{ item[field] ?? '-' }}</span>
          </div>
          <div v-if="$slots.actions" class="m-record-actions">
            <slot name="actions" :item="item" />
          </div>
        </div>
      </div>
      <div v-else class="wb-table-wrap">
        <table class="wb-table">
          <thead>
            <tr>
              <th v-for="field in fields" :key="field">{{ label(field) }}</th>
              <th v-if="$slots.actions" class="wb-col-actions">操作</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="item in paginatedItems" :key="item.id">
              <td v-for="field in fields" :key="field">{{ item[field] ?? '-' }}</td>
              <td v-if="$slots.actions" class="wb-table-actions">
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
        :mobile="mobile"
        @update:page="goPage"
        @update:page-size="setPageSize"
      />
    </template>
  </div>
</template>

<script setup>
import { toRef } from 'vue'
import PaginationBar from './PaginationBar.vue'
import { usePagination } from '../composables/usePagination'

const props = defineProps({
  title: String,
  items: Array,
  fields: Array,
  labels: Object,
  mobile: Boolean,
  pageSize: { type: Number, default: undefined }
})

const itemsRef = toRef(props, 'items')
const {
  page,
  pageSize,
  pageSizeOptions,
  total,
  totalPages,
  paginatedItems,
  rangeStart,
  rangeEnd,
  goPage
} = usePagination(itemsRef, {
  pageSize: props.pageSize ?? (props.mobile ? 8 : 10)
})

function setPageSize(value) {
  pageSize.value = value
}

function label(field) {
  return props.labels?.[field] || field
}
</script>
