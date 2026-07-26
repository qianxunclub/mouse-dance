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

      <div class="site-nav-actions">
        <StarButtons compact />
        <RouterLink to="/get-started.html" class="site-nav-cta">快速上手</RouterLink>
      </div>
    </div>
  </header>
</template>

<style scoped>
.site-nav {
  position: fixed;
  top: 16px;
  left: 50%;
  transform: translateX(-50%);
  z-index: 100;
  width: min(var(--md-max-width), calc(100% - 32px));
  border-radius: 999px;
  border: 1px solid var(--md-glass-border);
  background: linear-gradient(165deg, rgba(255, 255, 255, 0.1), rgba(255, 255, 255, 0.035));
  -webkit-backdrop-filter: blur(24px) saturate(180%);
  backdrop-filter: blur(24px) saturate(180%);
  box-shadow:
    inset 0 1px 0 rgba(255, 255, 255, 0.24),
    inset 0 -1px 0 rgba(255, 255, 255, 0.05),
    0 16px 44px rgba(3, 5, 12, 0.4);
  transition:
    background 0.35s ease,
    border-color 0.35s ease,
    box-shadow 0.35s ease;
}

.site-nav--scrolled {
  background: linear-gradient(165deg, rgba(24, 27, 43, 0.66), rgba(13, 16, 26, 0.55));
  border-color: rgba(255, 255, 255, 0.2);
  box-shadow:
    inset 0 1px 0 rgba(255, 255, 255, 0.28),
    inset 0 -1px 0 rgba(255, 255, 255, 0.06),
    0 20px 52px rgba(3, 5, 12, 0.55);
}

.site-nav-inner {
  padding: 0 12px 0 22px;
  height: 58px;
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
  box-shadow: 0 2px 10px rgba(10, 132, 255, 0.5);
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

.site-nav-actions {
  display: flex;
  align-items: center;
  gap: 12px;
}

.site-nav-cta {
  padding: 8px 18px;
  border-radius: 999px;
  font-size: 14px;
  font-weight: 600;
  color: #fff;
  background: var(--md-gradient);
  box-shadow: 0 4px 16px rgba(10, 132, 255, 0.38);
  transition:
    transform 0.25s ease,
    box-shadow 0.25s ease;
}

.site-nav-cta:hover {
  transform: translateY(-1px);
  box-shadow: 0 8px 22px rgba(100, 210, 255, 0.45);
}

@media (max-width: 768px) {
  .site-nav-links {
    display: none;
  }

  .star-buttons {
    display: none;
  }
}
</style>
