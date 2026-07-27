<script setup>
import { ref } from 'vue'
import { revealSectionHeader, useGsapScope } from '../../composables/useGsap'

const rootRef = ref(null)

useGsapScope(() => rootRef.value, (gsap) => {
  revealSectionHeader(gsap)
  gsap.from('.feature-card', {
    autoAlpha: 0,
    y: 48,
    duration: 0.85,
    stagger: 0.09,
    ease: 'power3.out',
    scrollTrigger: { trigger: '.features-grid', start: 'top 84%', once: true },
  })
})

// 卡片光斑跟随指针
const onCardMove = (e) => {
  const card = e.currentTarget
  const r = card.getBoundingClientRect()
  card.style.setProperty('--glow-x', `${e.clientX - r.left}px`)
  card.style.setProperty('--glow-y', `${e.clientY - r.top}px`)
}

const features = [
  {
    title: '多屏快捷键跳转',
    desc: '为每一块屏幕单独录制快捷键，按下后鼠标立即跳到对应屏幕中央，指哪打哪。',
    icon: 'M2 4h20v12H2z M8 20h8 M12 16v4 M7 8l3 8 1-3.5L14.5 11z',
  },
  {
    title: '快捷切换',
    desc: '一个全局快捷键，在当前屏幕与上一个活跃屏幕之间来回切换鼠标，就像窗口切换一样顺手。',
    icon: 'M17 2l4 4-4 4 M21 6H8 M7 22l-4-4 4-4 M3 18h13',
  },
  {
    title: '双击修饰键支持',
    desc: '支持录入双击 Command / Control / Option 这类轻量快捷键，不占组合键，零学习成本。',
    icon: 'M13 2L4.5 13.5H11L10 22l8.5-11.5H12z',
  },
  {
    title: '屏幕标记',
    desc: '一键在所有屏幕上叠加显示编号与已配置的快捷键，多屏排布一眼确认。',
    icon: 'M3 7V5a2 2 0 0 1 2-2h2 M17 3h2a2 2 0 0 1 2 2v2 M21 17v2a2 2 0 0 1-2 2h-2 M7 21H5a2 2 0 0 1-2-2v-2 M9 12h6 M12 9v6',
  },
  {
    title: '开机自启动',
    desc: '登录系统后自动常驻菜单栏运行，程序坞不显示图标，安静陪伴不打扰。',
    icon: 'M18.36 6.64a9 9 0 1 1-12.72 0 M12 2v10',
  },
  {
    title: '菜单栏快捷操作',
    desc: '菜单栏图标可直接跳转到指定屏幕、查看权限与自启动状态，不开窗口也能操作。',
    icon: 'M3 5h18 M3 5v3h18z M6 12h4 M6 16h7 M17 12l2.5 5.5L20 14l3.5-.5z',
  },
]
</script>

<template>
  <section class="md-section features" id="features" ref="rootRef">
    <div class="md-container">
      <span class="md-section-tag">功能特性</span>
      <h2 class="md-section-title">
        为<span class="md-gradient-text">多屏工作流</span>而生
      </h2>
      <p class="md-section-desc">
        常驻菜单栏的轻量工具，把"跨屏移动鼠标"这件小事做到极致。
      </p>

      <div class="features-grid">
        <article v-for="feature in features" :key="feature.title" class="feature-card" @mousemove="onCardMove">
          <div class="feature-icon">
            <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
              <path v-for="(d, i) in feature.icon.split(' M')" :key="i" :d="i === 0 ? d : 'M' + d" />
            </svg>
          </div>
          <h3 class="feature-title">{{ feature.title }}</h3>
          <p class="feature-desc">{{ feature.desc }}</p>
        </article>
      </div>
    </div>
  </section>
</template>

<style scoped>
.features {
  background: radial-gradient(ellipse 60% 40% at 85% 0%, rgba(10, 132, 255, 0.1), transparent 70%);
}

.features-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 20px;
  margin-top: 52px;
}

.feature-card {
  position: relative;
  padding: 28px;
  border-radius: 20px;
  border: 1px solid var(--md-glass-border);
  background: linear-gradient(165deg, rgba(255, 255, 255, 0.1), rgba(255, 255, 255, 0.035) 42%, rgba(255, 255, 255, 0.015));
  -webkit-backdrop-filter: blur(22px) saturate(170%);
  backdrop-filter: blur(22px) saturate(170%);
  box-shadow:
    inset 0 1px 0 rgba(255, 255, 255, 0.22),
    inset 0 -1px 0 rgba(255, 255, 255, 0.05),
    0 20px 50px rgba(3, 5, 12, 0.4);
  transition:
    transform 0.35s cubic-bezier(0.22, 1, 0.36, 1),
    border-color 0.35s ease,
    box-shadow 0.35s ease;
  overflow: hidden;
}

.feature-card::before {
  content: '';
  position: absolute;
  inset: 0;
  background: radial-gradient(320px circle at var(--glow-x, 50%) var(--glow-y, 0%), rgba(255, 255, 255, 0.14), transparent 70%);
  opacity: 0;
  transition: opacity 0.35s ease;
}

.feature-card:hover {
  transform: translateY(-6px);
  border-color: rgba(255, 255, 255, 0.26);
  box-shadow:
    inset 0 1px 0 rgba(255, 255, 255, 0.3),
    inset 0 -1px 0 rgba(255, 255, 255, 0.06),
    0 26px 60px rgba(3, 5, 12, 0.55);
}

.feature-card:hover::before {
  opacity: 1;
}

.feature-icon {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 46px;
  height: 46px;
  border-radius: 13px;
  color: #64d2ff;
  background: linear-gradient(165deg, rgba(255, 255, 255, 0.16), rgba(255, 255, 255, 0.05));
  border: 1px solid rgba(255, 255, 255, 0.22);
  box-shadow:
    inset 0 1px 0 rgba(255, 255, 255, 0.3),
    0 6px 18px rgba(10, 132, 255, 0.28);
}

.feature-title {
  margin: 18px 0 0;
  font-size: 18px;
  font-weight: 600;
}

.feature-desc {
  margin: 10px 0 0;
  font-size: 14px;
  line-height: 1.75;
  color: var(--md-text-dim);
}

@media (max-width: 960px) {
  .features-grid {
    grid-template-columns: repeat(2, 1fr);
  }
}

@media (max-width: 640px) {
  .features-grid {
    grid-template-columns: 1fr;
    gap: 14px;
    margin-top: 36px;
  }

  .feature-card {
    padding: 20px;
    border-radius: 16px;
  }

  .feature-title {
    font-size: 16px;
    margin-top: 14px;
  }

  .feature-desc {
    font-size: 13px;
    margin-top: 8px;
  }

  .feature-icon {
    width: 40px;
    height: 40px;
    border-radius: 11px;
  }
}
</style>
