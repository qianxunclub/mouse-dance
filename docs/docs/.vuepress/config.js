import { sitemapPlugin } from '@vuepress/plugin-sitemap'
import { commentPlugin } from '@vuepress/plugin-comment'
import { defaultTheme } from '@vuepress/theme-default'
import { defineUserConfig } from 'vuepress'
import { viteBundler } from '@vuepress/bundler-vite'

const siteBase = '/'
const withSiteBase = (path) => `${siteBase}${path.replace(/^\//, '')}`

const SITE_URL = 'https://mouse-dance.com'
const SITE_NAME = 'MouseDance'
const SITE_TITLE = 'MouseDance - macOS 多显示器鼠标快速跳转工具'
const SITE_DESC = '一款常驻 macOS 菜单栏的多显示器鼠标跳转工具：为每块屏幕配置独立快捷键，一键跳转鼠标，告别跨屏拖拽。免费开源，支持 macOS Tahoe 液态玻璃设计。'

export default defineUserConfig({
  base: siteBase,

  lang: 'zh-CN',

  title: SITE_TITLE,
  description: SITE_DESC,

  head: [
    // ── Favicon ──
    ['link', { rel: 'icon', type: 'image/png', href: withSiteBase('/images/AppIcon.png') }],
    ['link', { rel: 'apple-touch-icon', href: withSiteBase('/images/AppIcon.png') }],

    // ── 搜索引擎验证 / 索引 ──
    ['meta', { name: 'baidu-site-verification', content: 'codeva-Yb3mPk56pd' }],
    ['meta', { name: 'robots', content: 'index, follow' }],
    ['meta', { name: 'googlebot', content: 'index, follow' }],

    // ── Canonical URL ──
    ['link', { rel: 'canonical', href: SITE_URL }],

    // ── Open Graph / Facebook ──
    ['meta', { property: 'og:type', content: 'website' }],
    ['meta', { property: 'og:url', content: SITE_URL }],
    ['meta', { property: 'og:title', content: SITE_TITLE }],
    ['meta', { property: 'og:description', content: SITE_DESC }],
    ['meta', { property: 'og:site_name', content: SITE_NAME }],
    ['meta', { property: 'og:locale', content: 'zh_CN' }],
    ['meta', { property: 'og:image', content: `${SITE_URL}${withSiteBase('/images/AppIcon.png')}` }],
    ['meta', { property: 'og:image:width', content: '1024' }],
    ['meta', { property: 'og:image:height', content: '1024' }],
    ['meta', { property: 'og:image:alt', content: 'MouseDance 应用图标' }],

    // ── Twitter Card ──
    ['meta', { name: 'twitter:card', content: 'summary' }],
    ['meta', { name: 'twitter:title', content: SITE_TITLE }],
    ['meta', { name: 'twitter:description', content: SITE_DESC }],
    ['meta', { name: 'twitter:image', content: `${SITE_URL}${withSiteBase('/images/AppIcon.png')}` }],
    ['meta', { name: 'twitter:image:alt', content: 'MouseDance 应用图标' }],

    // ── JSON-LD 结构化数据 ──
    [
      'script',
      { type: 'application/ld+json' },
      JSON.stringify({
        '@context': 'https://schema.org',
        '@type': 'SoftwareApplication',
        name: 'MouseDance',
        applicationCategory: 'UtilitiesApplication',
        operatingSystem: 'macOS',
        description: SITE_DESC,
        url: SITE_URL,
        image: `${SITE_URL}${withSiteBase('/images/AppIcon.png')}`,
        offers: { '@type': 'Offer', price: '0', priceCurrency: 'CNY' },
        author: {
          '@type': 'Organization',
          name: 'qianxunclub',
          url: 'https://gitee.com/qianxunclub',
        },
      }),
    ],

    // ── 资源预连接 ──
    ['link', { rel: 'preconnect', href: 'https://api.fontshare.com' }],
    ['link', { rel: 'dns-prefetch', href: 'https://www.googletagmanager.com' }],
    ['link', { rel: 'dns-prefetch', href: 'https://hm.baidu.com' }],

    // ── 统计分析 ──
    [
      'script',
      { async: true, src: 'https://busuanzi.ibruce.info/busuanzi/2.3/busuanzi.pure.mini.js' },
    ],
    [
      'script',
      { async: true, src: 'https://www.googletagmanager.com/gtag/js?id=G-YCZ727X47D' },
    ],
    [
      'script',
      {},
      `window.dataLayer = window.dataLayer || [];
function gtag(){dataLayer.push(arguments);}
gtag('js', new Date());
gtag('config', 'G-YCZ727X47D');`,
    ],
    [
      'script',
      {},
      `var _hmt = _hmt || [];
(function() {
  var hm = document.createElement("script");
  hm.src = "https://hm.baidu.com/hm.js?078b2a0718b368b90a08050d32d5f517";
  var s = document.getElementsByTagName("script")[0];
  s.parentNode.insertBefore(hm, s);
})();`,
    ],

    // ── 字体 ──
    [
      'link',
      {
        rel: 'stylesheet',
        href: 'https://api.fontshare.com/v2/css?f[]=clash-display@500,600,700&f[]=satoshi@400,500,700&display=swap',
      },
    ],
  ],

  plugins: [
    sitemapPlugin({
      hostname: SITE_URL,
      extraUrls: [],
      devServer: true,
    }),
    commentPlugin({
      provider: 'Giscus',
      repo: 'qianxunclub/mouse-dance',
      repoId: 'R_kgDOTdKXlQ',
      category: 'Announcements',
      categoryId: 'DIC_kwDOTdKXlc4DCEZF',
      strict: 0,
      mapping: 'pathname',
      lang: 'zh-CN',
      reactionsEnabled: true,
      emitMetadata: 0,
      inputPosition: 'top',
      lazyLoading: true,
      darkTheme: 'dark',
    }),
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
