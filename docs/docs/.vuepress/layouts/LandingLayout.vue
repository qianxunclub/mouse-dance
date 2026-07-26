<script setup>
import SiteNav from '../components/landing/SiteNav.vue'
import { ref } from 'vue'
import { useGsapScope } from '../composables/useGsap'

const landingRef = ref(null)

useGsapScope(() => landingRef.value, (gsap) => {
  // 极光背景整体随滚动缓慢上移，与前景形成视差纵深
  gsap.to('.md-aurora', {
    yPercent: -14,
    ease: 'none',
    scrollTrigger: {
      trigger: landingRef.value,
      start: 'top top',
      end: 'max',
      scrub: 1.2,
    },
  })
})
</script>

<template>
  <div class="md-landing" ref="landingRef">
    <div class="md-aurora" aria-hidden="true">
      <span class="md-aurora-blob md-aurora-blob--1"></span>
      <span class="md-aurora-blob md-aurora-blob--2"></span>
      <span class="md-aurora-blob md-aurora-blob--3"></span>
      <span class="md-aurora-blob md-aurora-blob--4"></span>
    </div>
    <SiteNav />
    <div class="md-landing-content">
      <Content />
    </div>
  </div>
</template>

<style>
/* 全站极光背景：Liquid Glass 需要多彩底色供其折射 */
.md-landing {
  position: relative;
}

.md-landing-content {
  position: relative;
  z-index: 1;
}

.md-aurora {
  position: fixed;
  inset: 0;
  z-index: 0;
  overflow: hidden;
  background: var(--md-bg);
  pointer-events: none;
}

.md-aurora-blob {
  position: absolute;
  border-radius: 50%;
  filter: blur(90px);
  opacity: 0.55;
  will-change: transform;
}

.md-aurora-blob--1 {
  width: 55vw;
  height: 55vw;
  top: -18vw;
  left: -12vw;
  background: radial-gradient(circle at 35% 35%, rgba(10, 132, 255, 0.62), transparent 65%);
  animation: md-aurora-drift-1 26s ease-in-out infinite;
}

.md-aurora-blob--2 {
  width: 46vw;
  height: 46vw;
  top: -8vw;
  right: -10vw;
  background: radial-gradient(circle at 60% 40%, rgba(100, 210, 255, 0.4), transparent 65%);
  animation: md-aurora-drift-2 32s ease-in-out infinite;
}

.md-aurora-blob--3 {
  width: 52vw;
  height: 52vw;
  bottom: -20vw;
  left: 8vw;
  background: radial-gradient(circle at 45% 55%, rgba(99, 230, 226, 0.38), transparent 65%);
  animation: md-aurora-drift-3 29s ease-in-out infinite;
}

.md-aurora-blob--4 {
  width: 40vw;
  height: 40vw;
  bottom: -10vw;
  right: 4vw;
  background: radial-gradient(circle at 55% 45%, rgba(10, 132, 255, 0.36), transparent 65%);
  animation: md-aurora-drift-1 35s ease-in-out infinite reverse;
}

@keyframes md-aurora-drift-1 {
  0%,
  100% {
    transform: translate(0, 0) scale(1);
  }
  50% {
    transform: translate(6vw, 4vw) scale(1.12);
  }
}

@keyframes md-aurora-drift-2 {
  0%,
  100% {
    transform: translate(0, 0) scale(1);
  }
  50% {
    transform: translate(-5vw, 6vw) scale(0.92);
  }
}

@keyframes md-aurora-drift-3 {
  0%,
  100% {
    transform: translate(0, 0) scale(1);
  }
  50% {
    transform: translate(4vw, -5vw) scale(1.08);
  }
}

@media (prefers-reduced-motion: reduce) {
  .md-aurora-blob {
    animation: none;
  }
}
</style>
