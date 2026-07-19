export const siteData = JSON.parse("{\"base\":\"/mouse-dance/\",\"lang\":\"zh-CN\",\"title\":\"MouseDance\",\"description\":\"一款常驻菜单栏的 macOS 小工具：为多显示器用户的每一块屏幕配置独立快捷键，按下快捷键即可让鼠标瞬间跳到目标屏幕。\",\"head\":[[\"link\",{\"rel\":\"icon\",\"href\":\"/images/AppIcon.png\"}],[\"link\",{\"rel\":\"preconnect\",\"href\":\"https://api.fontshare.com\"}],[\"link\",{\"rel\":\"stylesheet\",\"href\":\"https://api.fontshare.com/v2/css?f[]=clash-display@500,600,700&f[]=satoshi@400,500,700&display=swap\"}]],\"locales\":{}}")

if (import.meta.webpackHot) {
  import.meta.webpackHot.accept()
  if (__VUE_HMR_RUNTIME__.updateSiteData) {
    __VUE_HMR_RUNTIME__.updateSiteData(siteData)
  }
}

if (import.meta.hot) {
  import.meta.hot.accept(({ siteData }) => {
    __VUE_HMR_RUNTIME__.updateSiteData(siteData)
  })
}
