import comp from "/Users/qianxunclub/workspace/mouse-dance/docs/docs/.vuepress/.temp/pages/index.html.vue"
const data = JSON.parse("{\"path\":\"/\",\"title\":\"MouseDance - 让鼠标在屏幕间起舞\",\"lang\":\"zh-CN\",\"frontmatter\":{\"layout\":\"LandingLayout\",\"title\":\"MouseDance - 让鼠标在屏幕间起舞\",\"description\":\"一款常驻菜单栏的 macOS 小工具：为多显示器用户的每一块屏幕配置独立快捷键，按下快捷键即可让鼠标瞬间跳到目标屏幕。\"},\"headers\":[],\"git\":{\"contributors\":[{\"name\":\"千寻啊千寻\",\"username\":\"\",\"email\":\"960339491@qq.com\",\"commits\":1}],\"changelog\":[{\"hash\":\"5106249538464fb64c92534ce7a96f83a886959b\",\"time\":1784463334000,\"email\":\"960339491@qq.com\",\"author\":\"千寻啊千寻\",\"message\":\"docs: 新增完整的 VuePress 项目文档站点\"}]},\"filePathRelative\":\"README.md\"}")
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
