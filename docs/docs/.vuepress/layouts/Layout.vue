<script setup>
import { useDarkMode } from '@vuepress/theme-default/client'
import DefaultThemeLayout from '@vuepress/theme-default/layouts/Layout.vue'

const isDark = useDarkMode()
</script>

<template>
  <DefaultThemeLayout>
    <template #page-bottom>
      <CommentService :darkmode="isDark" />
    </template>
  </DefaultThemeLayout>
</template>
