<script setup>
import { withBase } from 'vuepress/client'
import { onBeforeUnmount, onMounted, ref } from 'vue'

const scrolled = ref(false)

const onScroll = () => {
  scrolled.value = window.scrollY > 8
}

onMounted(() => {
  onScroll()
  window.addEventListener('scroll', onScroll, { passive: true })
})

onBeforeUnmount(() => {
  window.removeEventListener('scroll', onScroll)
})

const links = [
  { text: '功能', href: '#features' },
  { text: '演示', href: '#demo' },
  { text: '截图', href: '#screenshot' },
  { text: '下载', href: '#download' },
  { text: '常见问题', href: '#faq' },
]
</script>

<template>
  <header class="site-nav" :class="{ 'site-nav--scrolled': scrolled }">
    <div class="site-nav-inner">
      <a class="site-nav-brand" href="#top">
        <img :src="withBase('/images/AppIcon.png')" alt="MouseDance 图标" class="site-nav-logo" />
        <span class="site-nav-name">MouseDance</span>
      </a>

      <nav class="site-nav-links" aria-label="页面导航">
        <a v-for="link in links" :key="link.href" :href="link.href" class="site-nav-link">
          {{ link.text }}
        </a>
      </nav>

      <RouterLink to="/get-started.html" class="site-nav-cta">快速上手</RouterLink>
    </div>
  </header>
</template>

<style scoped>
.site-nav {
  position: fixed;
  inset: 0 0 auto 0;
  z-index: 100;
  transition:
    background 0.35s ease,
    border-color 0.35s ease,
    backdrop-filter 0.35s ease;
  border-bottom: 1px solid transparent;
}

.site-nav--scrolled {
  background: rgba(11, 13, 20, 0.72);
  backdrop-filter: blur(18px) saturate(1.4);
  -webkit-backdrop-filter: blur(18px) saturate(1.4);
  border-bottom-color: var(--md-border);
}

.site-nav-inner {
  max-width: var(--md-max-width);
  margin: 0 auto;
  padding: 0 24px;
  height: 64px;
  display: flex;
  align-items: center;
  gap: 32px;
}

.site-nav-brand {
  display: inline-flex;
  align-items: center;
  gap: 10px;
  font-family: var(--md-font-display);
  font-weight: 600;
  font-size: 17px;
}

.site-nav-logo {
  width: 30px;
  height: 30px;
  border-radius: 8px;
  box-shadow: 0 2px 10px rgba(99, 102, 241, 0.45);
}

.site-nav-links {
  display: flex;
  align-items: center;
  gap: 4px;
  margin-left: auto;
}

.site-nav-link {
  padding: 8px 14px;
  border-radius: 999px;
  font-size: 14px;
  color: var(--md-text-dim);
  transition:
    color 0.25s ease,
    background 0.25s ease;
}

.site-nav-link:hover {
  color: var(--md-text);
  background: rgba(255, 255, 255, 0.06);
}

.site-nav-cta {
  padding: 8px 18px;
  border-radius: 999px;
  font-size: 14px;
  font-weight: 600;
  color: #fff;
  background: var(--md-gradient);
  box-shadow: 0 4px 16px rgba(99, 102, 241, 0.35);
  transition:
    transform 0.25s ease,
    box-shadow 0.25s ease;
}

.site-nav-cta:hover {
  transform: translateY(-1px);
  box-shadow: 0 8px 22px rgba(139, 92, 246, 0.45);
}

@media (max-width: 768px) {
  .site-nav-links {
    display: none;
  }
}
</style>
