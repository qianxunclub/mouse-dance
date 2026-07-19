export const themeData = JSON.parse("{\"logo\":\"/images/AppIcon.png\",\"colorMode\":\"dark\",\"colorModeSwitch\":false,\"navbar\":[{\"text\":\"首页\",\"link\":\"/\"},{\"text\":\"快速上手\",\"link\":\"/get-started\"},{\"text\":\"Gitee\",\"link\":\"https://gitee.com/qianxunclub/mouse-dance\"}],\"editLink\":false,\"lastUpdated\":false,\"contributors\":false,\"locales\":{\"/\":{\"selectLanguageName\":\"English\"}},\"repo\":null,\"selectLanguageText\":\"Languages\",\"selectLanguageAriaLabel\":\"Select language\",\"sidebar\":\"heading\",\"sidebarDepth\":2,\"editLinkText\":\"Edit this page\",\"contributorsText\":\"Contributors\",\"notFound\":[\"There's nothing here.\",\"How did we get here?\",\"That's a Four-Oh-Four.\",\"Looks like we've got some broken links.\"],\"backToHome\":\"Take me home\",\"openInNewWindow\":\"open in new window\",\"toggleColorMode\":\"toggle color mode\",\"toggleSidebar\":\"toggle sidebar\"}")

if (import.meta.webpackHot) {
  import.meta.webpackHot.accept()
  if (__VUE_HMR_RUNTIME__.updateThemeData) {
    __VUE_HMR_RUNTIME__.updateThemeData(themeData)
  }
}

if (import.meta.hot) {
  import.meta.hot.accept(({ themeData }) => {
    __VUE_HMR_RUNTIME__.updateThemeData(themeData)
  })
}
