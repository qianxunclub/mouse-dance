// 组件注册与自定义布局
import { defineClientConfig } from 'vuepress/client'
import LandingLayout from './layouts/LandingLayout.vue'
import HomeLanding from './components/HomeLanding.vue'

export default defineClientConfig({
  enhance({ app }) {
    app.component('HomeLanding', HomeLanding)
  },
  layouts: {
    LandingLayout,
  },
})
