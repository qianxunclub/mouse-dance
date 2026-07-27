// 组件注册与自定义布局
import { defineClientConfig } from 'vuepress/client'
import Layout from './layouts/Layout.vue'
import LandingLayout from './layouts/LandingLayout.vue'
import HomeLanding from './components/HomeLanding.vue'
import StarButtons from './components/landing/StarButtons.vue'

const BUSUANZI_SCRIPT_URL = 'https://busuanzi.ibruce.info/busuanzi/2.3/busuanzi.pure.mini.js'

const reloadBusuanzi = () => {
  document.querySelectorAll('script[data-busuanzi-reload]').forEach((node) => node.remove())
  const script = document.createElement('script')
  script.async = true
  script.src = `${BUSUANZI_SCRIPT_URL}?_=${Date.now()}`
  script.dataset.busuanziReload = 'true'
  document.head.appendChild(script)
}

export default defineClientConfig({
  enhance({ app, router }) {
    app.component('HomeLanding', HomeLanding)
    app.component('StarButtons', StarButtons)

    if (typeof window === 'undefined') return

    let isInitialNavigation = true
    router.afterEach(() => {
      if (isInitialNavigation) {
        isInitialNavigation = false
        return
      }
      reloadBusuanzi()
    })
  },
  layouts: {
    Layout,
    LandingLayout,
  },
})
