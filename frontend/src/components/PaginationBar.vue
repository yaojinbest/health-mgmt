<template>
  <footer v-if="total > 0" class="list-pagination" :class="{ compact: mobile }">
    <span class="list-pagination-info">
      第 {{ rangeStart }}-{{ rangeEnd }} 条，共 {{ total }} 条
    </span>
    <div class="list-pagination-controls">
      <label v-if="!mobile" class="list-pagination-size">
        每页
        <select :value="pageSize" @change="onSizeChange">
          <option v-for="size in pageSizeOptions" :key="size" :value="size">{{ size }}</option>
        </select>
        条
      </label>
      <button type="button" class="list-page-btn" :disabled="page <= 1" @click="goPage(page - 1)">上一页</button>
      <span class="list-page-indicator">{{ page }} / {{ totalPages }}</span>
      <button type="button" class="list-page-btn" :disabled="page >= totalPages" @click="goPage(page + 1)">下一页</button>
    </div>
  </footer>
</template>

<script setup>
const props = defineProps({
  page: { type: Number, required: true },
  pageSize: { type: Number, required: true },
  total: { type: Number, required: true },
  totalPages: { type: Number, required: true },
  rangeStart: { type: Number, required: true },
  rangeEnd: { type: Number, required: true },
  pageSizeOptions: { type: Array, default: () => [10, 20, 50] },
  mobile: { type: Boolean, default: false }
})

const emit = defineEmits(['update:page', 'update:pageSize'])

function goPage(nextPage) {
  emit('update:page', nextPage)
}

function onSizeChange(event) {
  emit('update:pageSize', Number(event.target.value))
}
</script>
