<template>
  <div class="adm-shell">
    <header class="adm-page-head">
      <div class="adm-page-head-main">
        <span v-if="icon" class="adm-page-icon">{{ icon }}</span>
        <div>
          <h1>{{ title }}</h1>
          <p v-if="subtitle">{{ subtitle }}</p>
        </div>
      </div>
      <div v-if="$slots.actions" class="adm-page-actions">
        <slot name="actions" />
      </div>
    </header>
    <slot />
  </div>
</template>

<script setup>
defineProps({
  icon: String,
  title: String,
  subtitle: String
})
</script>
