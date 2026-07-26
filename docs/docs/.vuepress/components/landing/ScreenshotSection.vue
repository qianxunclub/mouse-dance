<script setup>
import { withBase } from 'vuepress/client'
import { ref } from 'vue'
import { revealSectionHeader, useGsapScope } from '../../composables/useGsap'

const rootRef = ref(null)

useGsapScope(() => rootRef.value, (gsap) => {
  revealSectionHeader(gsap)

  // 窗口入场，完成后进入持续悬浮
  gsap.from('.shot-window', {
    autoAlpha: 0,
    y: 72,
    scale: 0.93,
    duration: 1.05,
    ease: 'power3.out',
    scrollTrigger: { trigger: '.shot-frame', start: 'top 82%', once: true },
    onComplete: () => {
      gsap.to('.shot-window', {
        y: -10,
        duration: 3.2,
        ease: 'sine.inOut',
        yoyo: true,
        repeat: -1,
      })
    },
  })

  // 光晕随滚动缓慢上移，营造纵深
  gsap.to('.shot-glow', {
    yPercent: -22,
    ease: 'none',
    scrollTrigger: { trigger: '.shot-frame', start: 'top bottom', end: 'bottom top', scrub: 1 },
  })
})
</script>

<template>
  <section class="md-section shot" id="screenshot" ref="rootRef">
    <div class="md-container">
      <span class="md-section-tag">真实界面</span>
      <h2 class="md-section-title">深色原生，<span class="md-gradient-text">所见即所得</span></h2>
      <p class="md-section-desc">
        全局配置与屏幕配置集中在一个窗口：权限状态、快捷切换、开机自启动、每块屏幕的快捷键，一目了然。
      </p>

      <div class="shot-frame">
        <div class="shot-glow" aria-hidden="true"></div>
        <div class="shot-window">
          <div class="shot-titlebar">
            <span class="shot-light shot-light--red"></span>
            <span class="shot-light shot-light--yellow"></span>
            <span class="shot-light shot-light--green"></span>
            <span class="shot-titlebar-text">MouseDance</span>
          </div>
          <img :src="withBase('/images/screenshot.png')" alt="MouseDance 设置窗口截图" class="shot-image" />
        </div>
      </div>
    </div>
  </section>
</template>

<style scoped>
.shot {
  background: transparent;
}

.shot-frame {
  position: relative;
  margin-top: 52px;
}

.shot-glow {
  position: absolute;
  inset: -8% -12%;
  background:
    radial-gradient(ellipse 45% 55% at 30% 40%, rgba(10, 132, 255, 0.3), transparent 70%),
    radial-gradient(ellipse 40% 50% at 72% 60%, rgba(100, 210, 255, 0.2), transparent 70%);
  filter: blur(60px);
  pointer-events: none;
}

.shot-window {
  position: relative;
  border-radius: 18px;
  border: 1px solid var(--md-glass-border);
  background: rgba(255, 255, 255, 0.04);
  overflow: hidden;
  box-shadow:
    inset 0 1px 0 rgba(255, 255, 255, 0.24),
    0 32px 90px rgba(3, 4, 8, 0.65);
}

.shot-titlebar {
  display: flex;
  align-items: center;
  gap: 8px;
  height: 38px;
  padding: 0 16px;
  border-bottom: 1px solid rgba(255, 255, 255, 0.1);
  background: linear-gradient(180deg, rgba(255, 255, 255, 0.12), rgba(255, 255, 255, 0.03));
  -webkit-backdrop-filter: blur(18px) saturate(160%);
  backdrop-filter: blur(18px) saturate(160%);
}

.shot-light {
  width: 12px;
  height: 12px;
  border-radius: 50%;
}

.shot-light--red {
  background: #ff5f57;
}

.shot-light--yellow {
  background: #febc2e;
}

.shot-light--green {
  background: #28c840;
}

.shot-titlebar-text {
  position: absolute;
  left: 50%;
  transform: translateX(-50%);
  font-size: 13px;
  color: var(--md-text-faint);
}

.shot-image {
  display: block;
  width: 100%;
  height: auto;
}
</style>
