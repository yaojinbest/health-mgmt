import { computed, ref, unref, watch } from 'vue'

export const DEFAULT_PAGE_SIZE = 10
export const PAGE_SIZE_OPTIONS = [10, 20, 50]

export function usePagination(itemsSource, options = {}) {
  const page = ref(1)
  const pageSize = ref(options.pageSize ?? DEFAULT_PAGE_SIZE)
  const pageSizeOptions = options.pageSizeOptions ?? PAGE_SIZE_OPTIONS

  const allItems = computed(() => {
    const value = typeof itemsSource === 'function' ? itemsSource() : unref(itemsSource)
    return value || []
  })

  const total = computed(() => allItems.value.length)
  const totalPages = computed(() => Math.max(1, Math.ceil(total.value / pageSize.value)))

  const paginatedItems = computed(() => {
    const start = (page.value - 1) * pageSize.value
    return allItems.value.slice(start, start + pageSize.value)
  })

  const rangeStart = computed(() => (total.value ? (page.value - 1) * pageSize.value + 1 : 0))
  const rangeEnd = computed(() => Math.min(page.value * pageSize.value, total.value))

  watch(totalPages, value => {
    if (page.value > value) page.value = value
    if (page.value < 1) page.value = 1
  })

  watch(pageSize, () => {
    page.value = 1
  })

  function goPage(nextPage) {
    page.value = Math.min(Math.max(1, nextPage), totalPages.value)
  }

  function resetPage() {
    page.value = 1
  }

  return {
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
  }
}
