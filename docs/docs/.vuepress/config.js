import { defaultTheme } from '@vuepress/theme-default'
import { defineUserConfig } from 'vuepress'
import { viteBundler } from '@vuepress/bundler-vite'

const siteBase = '/mouse-dance/'
const withSiteBase = (path) => `${siteBase}${path.replace(/^\//, '')}`

export default defineUserConfig({
  base: siteBase,

  lang: 'zh-CN',

  title: 'MouseDance',
  description: '一款常驻菜单栏的 macOS 小工具：为多显示器用户的每一块屏幕配置独立快捷键，按下快捷键即可让鼠标瞬间跳到目标屏幕。',

  head: [
    ['link', { rel: 'icon', href: withSiteBase('/images/AppIcon.png') }],
    ['link', { rel: 'preconnect', href: 'https://api.fontshare.com' }],
    [
      'link',
      {
        rel: 'stylesheet',
        href: 'https://api.fontshare.com/v2/css?f[]=clash-display@500,600,700&f[]=satoshi@400,500,700&display=swap',
      },
    ],
  ],

  theme: defaultTheme({
    logo: '/images/AppIcon.png',

    colorMode: 'dark',
    colorModeSwitch: false,

    navbar: [
      { text: '首页', link: '/' },
      { text: '快速上手', link: '/get-started' },
      { text: 'Gitee', link: 'https://gitee.com/qianxunclub/mouse-dance' },
    ],

    editLink: false,
    lastUpdated: false,
    contributors: false,
  }),

  bundler: viteBundler(),
})
