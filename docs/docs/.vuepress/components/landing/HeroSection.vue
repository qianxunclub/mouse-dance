<script setup>
import { withBase } from 'vuepress/client'
import { onBeforeUnmount, onMounted, ref } from 'vue'
import { isReducedMotion, makeMagnetic, useGsap } from '../../composables/useGsap'

const heroRef = ref(null)
let ctx
let cleanupMagnetic
let cleanupParallax

onMounted(() => {
  if (isReducedMotion() || !heroRef.value) return
  const { gsap } = useGsap()
  const hero = heroRef.value

  ctx = gsap.context(() => {
    // 应用图标持续悬浮
    gsap.to('.hero-icon', {
      y: -10,
      duration: 2.4,
      ease: 'sine.inOut',
      yoyo: true,
      repeat: -1,
    })

    // 向下滚动时 Hero 内容渐隐下沉
    gsap.to('.hero-content', {
      autoAlpha: 0.1,
      y: 90,
      ease: 'none',
      scrollTrigger: {
        trigger: hero,
        start: 'top top',
        end: 'bottom 40%',
        scrub: 0.6,
      },
    })

    // 鼠标视差：光晕与网格按深度分层跟随
    const layers = [
      { sel: '.hero-glow--left', depth: 34 },
      { sel: '.hero-glow--right', depth: -28 },
      { sel: '.hero-grid', depth: 12 },
    ].map(({ sel, depth }) => ({
      depth,
      xTo: gsap.quickTo(sel, 'x', { duration: 0.9, ease: 'power3' }),
      yTo: gsap.quickTo(sel, 'y', { duration: 0.9, ease: 'power3' }),
    }))

    const onMove = (e) => {
      const nx = e.clientX / window.innerWidth - 0.5
      const ny = e.clientY / window.innerHeight - 0.5
      layers.forEach(({ depth, xTo, yTo }) => {
        xTo(nx * depth)
        yTo(ny * depth)
      })
    }
    hero.addEventListener('mousemove', onMove)
    cleanupParallax = () => hero.removeEventListener('mousemove', onMove)
  }, hero)

  cleanupMagnetic = makeMagnetic(hero.querySelector('.hero-cta-magnet'), 0.3)
})

onBeforeUnmount(() => {
  ctx?.revert()
  cleanupMagnetic?.()
  cleanupParallax?.()
})
</script>

<template>
  <section class="hero" id="top" ref="heroRef">
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
        macOS 26+ · 常驻菜单栏 · 免费开源
      </div>

      <div class="hero-icon-wrap md-rise" style="animation-delay: 0.15s">
        <img
          :src="withBase('/images/AppIcon.png')"
          alt="MouseDance 应用图标"
          class="hero-icon"
        />
      </div>

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
        <span class="hero-cta-magnet">
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
        </span>
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
  background: radial-gradient(circle, rgba(10, 132, 255, 0.32), transparent 65%);
}

.hero-glow--right {
  bottom: -260px;
  right: -140px;
  background: radial-gradient(circle, rgba(100, 210, 255, 0.24), transparent 65%);
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
  filter: drop-shadow(0 0 14px rgba(100, 210, 255, 0.4));
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
  border: 1px solid var(--md-glass-border);
  background: linear-gradient(165deg, rgba(255, 255, 255, 0.12), rgba(255, 255, 255, 0.04));
  -webkit-backdrop-filter: blur(18px) saturate(170%);
  backdrop-filter: blur(18px) saturate(170%);
  box-shadow:
    inset 0 1px 0 rgba(255, 255, 255, 0.22),
    0 10px 30px rgba(3, 5, 12, 0.35);
  font-size: 13px;
  color: var(--md-text-dim);
}

.hero-badge-dot {
  width: 7px;
  height: 7px;
  border-radius: 50%;
  background: #30d158;
  box-shadow: 0 0 8px rgba(48, 209, 88, 0.8);
}

.hero-icon-wrap {
  margin-top: 34px;
}

.hero-icon {
  width: 118px;
  height: 118px;
  border-radius: 27px;
  box-shadow:
    0 0 0 1px rgba(255, 255, 255, 0.12),
    0 18px 50px rgba(10, 132, 255, 0.45),
    0 0 90px rgba(100, 210, 255, 0.28);
}

.hero-cta-magnet {
  display: inline-flex;
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
  border-radius: 7px;
  border: 1px solid var(--md-glass-border);
  border-bottom-width: 2px;
  background: linear-gradient(180deg, rgba(255, 255, 255, 0.16), rgba(255, 255, 255, 0.05));
  -webkit-backdrop-filter: blur(12px);
  backdrop-filter: blur(12px);
  box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.28);
  font-family: var(--md-font-mono);
  font-size: 12px;
  color: var(--md-text);
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
  border: 1px solid var(--md-glass-border);
  background: linear-gradient(165deg, rgba(255, 255, 255, 0.12), rgba(255, 255, 255, 0.04));
  -webkit-backdrop-filter: blur(14px);
  backdrop-filter: blur(14px);
  box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.22);
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
  .hero {
    padding: 80px 0 48px;
    min-height: 100svh;
  }

  .hero-br {
    display: none;
  }

  .hero-icon {
    width: 88px;
    height: 88px;
    border-radius: 20px;
  }

  .hero-icon-wrap {
    margin-top: 24px;
  }

  .hero-title {
    margin-top: 22px;
    font-size: clamp(32px, 9vw, 42px);
  }

  .hero-subtitle {
    margin-top: 16px;
    font-size: 15px;
    line-height: 1.7;
  }

  .hero-actions {
    flex-direction: column;
    align-items: center;
    gap: 10px;
    margin-top: 28px;
    width: 100%;
    padding: 0 12px;
  }

  .hero-actions .md-btn {
    width: 100%;
    max-width: 280px;
  }

  .hero-meta {
    flex-direction: column;
    gap: 10px;
    margin-top: 26px;
  }

  .hero-meta-divider {
    display: none;
  }

  .hero-glow {
    width: 320px;
    height: 320px;
  }

  .hero-glow--left {
    top: -100px;
    left: -60px;
  }

  .hero-glow--right {
    bottom: -130px;
    right: -70px;
  }

  .hero-cursor--a {
    width: 30px;
    left: 6%;
  }

  .hero-cursor--b {
    width: 22px;
    right: 6%;
  }

  .hero-scroll {
    bottom: 16px;
  }
}
</style>
