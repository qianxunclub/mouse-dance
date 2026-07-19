<script setup>
import { withBase } from 'vuepress/client'
</script>

<template>
  <section class="hero" id="top">
    <div class="hero-bg" aria-hidden="true">
      <div class="hero-glow hero-glow--left"></div>
      <div class="hero-glow hero-glow--right"></div>
      <div class="hero-grid"></div>
      <svg class="hero-cursor hero-cursor--a" viewBox="0 0 24 24" fill="none">
        <path d="M5 3l6.5 17 2-7.2 7.2-2L5 3z" fill="currentColor" />
      </svg>
      <svg class="hero-cursor hero-cursor--b" viewBox="0 0 24 24" fill="none">
        <path d="M5 3l6.5 17 2-7.2 7.2-2L5 3z" fill="currentColor" />
      </svg>
    </div>

    <div class="md-container hero-content">
      <div class="hero-badge md-rise" style="animation-delay: 0.05s">
        <span class="hero-badge-dot"></span>
        macOS 14+ · 常驻菜单栏 · 免费开源
      </div>

      <img
        :src="withBase('/images/AppIcon.png')"
        alt="MouseDance 应用图标"
        class="hero-icon md-rise"
        style="animation-delay: 0.15s"
      />

      <h1 class="hero-title md-rise" style="animation-delay: 0.25s">
        让鼠标在屏幕间
        <span class="md-gradient-text">起舞</span>
      </h1>

      <p class="hero-subtitle md-rise" style="animation-delay: 0.35s">
        为多显示器 macOS 用户的每一块屏幕配置独立快捷键，
        <br class="hero-br" />
        按下快捷键，鼠标瞬间跳到目标屏幕中央——不再拖着指针横穿桌面。
      </p>

      <div class="hero-actions md-rise" style="animation-delay: 0.45s">
        <a
          class="md-btn md-btn-primary"
          href="https://gitee.com/qianxunclub/mouse-dance/releases"
          target="_blank"
          rel="noopener"
        >
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4" />
            <polyline points="7 10 12 15 17 10" />
            <line x1="12" y1="15" x2="12" y2="3" />
          </svg>
          立即下载
        </a>
        <RouterLink to="/get-started.html" class="md-btn md-btn-ghost">快速上手</RouterLink>
      </div>

      <div class="hero-meta md-rise" style="animation-delay: 0.55s">
        <span class="hero-meta-item">
          <kbd>⌘</kbd><kbd>⌥</kbd><kbd>1</kbd>
          跳到屏幕 1
        </span>
        <span class="hero-meta-divider"></span>
        <span class="hero-meta-item">
          <kbd>⌘</kbd><kbd>⌥</kbd><kbd>2</kbd>
          跳到屏幕 2
        </span>
        <span class="hero-meta-divider"></span>
        <span class="hero-meta-item">
          <kbd>⌘</kbd><kbd>⌘</kbd>
          双击往返
        </span>
      </div>
    </div>

    <a class="hero-scroll" href="#features" aria-label="向下滚动">
      <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        <polyline points="6 9 12 15 18 9" />
      </svg>
    </a>
  </section>
</template>

<style scoped>
.hero {
  position: relative;
  min-height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  overflow: hidden;
  padding: 120px 0 80px;
}

.hero-bg {
  position: absolute;
  inset: 0;
  pointer-events: none;
}

.hero-glow {
  position: absolute;
  width: 640px;
  height: 640px;
  border-radius: 50%;
  filter: blur(120px);
}

.hero-glow--left {
  top: -200px;
  left: -120px;
  background: radial-gradient(circle, rgba(99, 102, 241, 0.32), transparent 65%);
}

.hero-glow--right {
  bottom: -260px;
  right: -140px;
  background: radial-gradient(circle, rgba(168, 85, 247, 0.26), transparent 65%);
}

.hero-grid {
  position: absolute;
  inset: 0;
  background-image:
    linear-gradient(rgba(255, 255, 255, 0.035) 1px, transparent 1px),
    linear-gradient(90deg, rgba(255, 255, 255, 0.035) 1px, transparent 1px);
  background-size: 56px 56px;
  mask-image: radial-gradient(ellipse 75% 65% at 50% 42%, #000 30%, transparent 75%);
  -webkit-mask-image: radial-gradient(ellipse 75% 65% at 50% 42%, #000 30%, transparent 75%);
}

.hero-cursor {
  position: absolute;
  color: rgba(255, 255, 255, 0.1);
  filter: drop-shadow(0 0 14px rgba(139, 92, 246, 0.35));
}

.hero-cursor--a {
  width: 44px;
  top: 22%;
  left: 12%;
  animation: hero-float-a 11s ease-in-out infinite;
}

.hero-cursor--b {
  width: 30px;
  bottom: 24%;
  right: 13%;
  animation: hero-float-b 13s ease-in-out infinite;
}

@keyframes hero-float-a {
  0%,
  100% {
    transform: translate(0, 0) rotate(-6deg);
  }
  50% {
    transform: translate(46px, -34px) rotate(4deg);
  }
}

@keyframes hero-float-b {
  0%,
  100% {
    transform: translate(0, 0) rotate(8deg);
  }
  50% {
    transform: translate(-38px, 30px) rotate(-5deg);
  }
}

.hero-content {
  position: relative;
  z-index: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  text-align: center;
}

.hero-badge {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  padding: 7px 16px;
  border-radius: 999px;
  border: 1px solid var(--md-border);
  background: rgba(255, 255, 255, 0.04);
  font-size: 13px;
  color: var(--md-text-dim);
}

.hero-badge-dot {
  width: 7px;
  height: 7px;
  border-radius: 50%;
  background: #34d399;
  box-shadow: 0 0 8px rgba(52, 211, 153, 0.8);
}

.hero-icon {
  width: 118px;
  height: 118px;
  margin-top: 34px;
  border-radius: 27px;
  box-shadow:
    0 0 0 1px rgba(255, 255, 255, 0.12),
    0 18px 50px rgba(99, 102, 241, 0.45),
    0 0 90px rgba(139, 92, 246, 0.3);
}

.hero-title {
  margin: 30px 0 0;
  font-size: clamp(42px, 7vw, 76px);
  font-weight: 600;
  line-height: 1.08;
  letter-spacing: -0.02em;
}

.hero-subtitle {
  margin: 22px 0 0;
  max-width: 620px;
  font-size: 17px;
  line-height: 1.75;
  color: var(--md-text-dim);
}

.hero-actions {
  display: flex;
  flex-wrap: wrap;
  justify-content: center;
  gap: 14px;
  margin-top: 38px;
}

.hero-meta {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  justify-content: center;
  gap: 14px;
  margin-top: 34px;
  font-size: 13px;
  color: var(--md-text-faint);
}

.hero-meta-item {
  display: inline-flex;
  align-items: center;
  gap: 6px;
}

.hero-meta-item kbd {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-width: 24px;
  height: 24px;
  padding: 0 6px;
  border-radius: 6px;
  border: 1px solid var(--md-border-strong);
  border-bottom-width: 2px;
  background: rgba(255, 255, 255, 0.05);
  font-family: var(--md-font-mono);
  font-size: 12px;
  color: var(--md-text-dim);
}

.hero-meta-divider {
  width: 1px;
  height: 16px;
  background: var(--md-border);
}

.hero-scroll {
  position: absolute;
  bottom: 26px;
  left: 50%;
  transform: translateX(-50%);
  display: flex;
  align-items: center;
  justify-content: center;
  width: 38px;
  height: 38px;
  border-radius: 50%;
  border: 1px solid var(--md-border);
  color: var(--md-text-faint);
  animation: hero-bounce 2.2s ease-in-out infinite;
  transition: color 0.25s ease;
}

.hero-scroll:hover {
  color: var(--md-text);
}

@keyframes hero-bounce {
  0%,
  100% {
    transform: translate(-50%, 0);
  }
  50% {
    transform: translate(-50%, 8px);
  }
}

@media (max-width: 640px) {
  .hero-br {
    display: none;
  }

  .hero-icon {
    width: 96px;
    height: 96px;
    border-radius: 22px;
  }
}
</style>
