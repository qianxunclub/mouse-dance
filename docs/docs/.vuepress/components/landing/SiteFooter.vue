<script setup>
import { withBase } from 'vuepress/client'
</script>

<template>
  <footer class="site-footer">
    <div class="md-container site-footer-inner">
      <div class="site-footer-brand">
        <img :src="withBase('/images/AppIcon.png')" alt="MouseDance 图标" class="site-footer-logo" />
        <div>
          <p class="site-footer-name">MouseDance</p>
          <p class="site-footer-slogan">让鼠标在屏幕间起舞</p>
        </div>
      </div>

      <div class="site-footer-right">
        <StarButtons />
        <nav class="site-footer-links" aria-label="页脚导航">
          <RouterLink to="/get-started.html" class="site-footer-link">快速上手</RouterLink>
          <a
            class="site-footer-link"
            href="https://gitee.com/qianxunclub/mouse-dance/releases"
            target="_blank"
            rel="noopener"
          >
            版本发布
          </a>
        </nav>
      </div>
    </div>

    <div class="md-container site-footer-bottom">
      <span>MIT Licensed</span>
      <span id="busuanzi_container_site_pv" class="site-footer-busuanzi" style="display: none">
        本站总访问量 <span id="busuanzi_value_site_pv"></span> 次
      </span>
      <span id="busuanzi_container_site_uv" class="site-footer-busuanzi" style="display: none">
        本站访客数 <span id="busuanzi_value_site_uv"></span> 人
      </span>
      <span>Copyright © {{ new Date().getFullYear() }} MouseDance</span>
    </div>
  </footer>
</template>

<style scoped>
.site-footer {
  border-top: 1px solid rgba(255, 255, 255, 0.1);
  background: linear-gradient(180deg, rgba(255, 255, 255, 0.04), transparent 30%);
  -webkit-backdrop-filter: blur(14px);
  backdrop-filter: blur(14px);
  padding: 48px 0 32px;
}

.site-footer-inner {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  justify-content: space-between;
  gap: 24px;
}

.site-footer-brand {
  display: flex;
  align-items: center;
  gap: 14px;
}

.site-footer-logo {
  width: 42px;
  height: 42px;
  border-radius: 11px;
  box-shadow: 0 4px 16px rgba(10, 132, 255, 0.4);
}

.site-footer-name {
  margin: 0;
  font-family: var(--md-font-display);
  font-size: 16px;
  font-weight: 600;
}

.site-footer-slogan {
  margin: 2px 0 0;
  font-size: 13px;
  color: var(--md-text-faint);
}

.site-footer-right {
  display: flex;
  flex-direction: column;
  align-items: flex-end;
  gap: 20px;
}

.site-footer-links {
  display: flex;
  flex-wrap: wrap;
  gap: 24px;
}

.site-footer-link {
  font-size: 14px;
  color: var(--md-text-dim);
  transition: color 0.25s ease;
}

.site-footer-link:hover {
  color: var(--md-text);
}

.site-footer-bottom {
  display: flex;
  flex-wrap: wrap;
  justify-content: space-between;
  gap: 8px;
  margin-top: 36px;
  padding-top: 24px;
  border-top: 1px solid var(--md-border);
  font-size: 13px;
  color: var(--md-text-faint);
}
</style>
