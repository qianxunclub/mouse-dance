import comp from "/Users/qianxunclub/workspace/mouse-dance/docs/docs/.vuepress/.temp/pages/index.html.vue"
const data = JSON.parse("{\"path\":\"/\",\"title\":\"MouseDance - 让鼠标在屏幕间起舞\",\"lang\":\"zh-CN\",\"frontmatter\":{\"layout\":\"LandingLayout\",\"title\":\"MouseDance - 让鼠标在屏幕间起舞\",\"description\":\"一款常驻菜单栏的 macOS 小工具：为多显示器用户的每一块屏幕配置独立快捷键，按下快捷键即可让鼠标瞬间跳到目标屏幕。\"},\"headers\":[],\"git\":{},\"filePathRelative\":\"README.md\"}")
export { comp, data }

if (import.meta.webpackHot) {
  import.meta.webpackHot.accept()
  if (__VUE_HMR_RUNTIME__.updatePageData) {
    __VUE_HMR_RUNTIME__.updatePageData(data)
  }
}

if (import.meta.hot) {
  import.meta.hot.accept(({ data }) => {
    __VUE_HMR_RUNTIME__.updatePageData(data)
  })
}
