<script setup>
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
  <section class="md-section features" id="features">
    <div class="md-container">
      <span class="md-section-tag">功能特性</span>
      <h2 class="md-section-title">
        为<span class="md-gradient-text">多屏工作流</span>而生
      </h2>
      <p class="md-section-desc">
        常驻菜单栏的轻量工具，把"跨屏移动鼠标"这件小事做到极致。
      </p>

      <div class="features-grid">
        <article v-for="feature in features" :key="feature.title" class="feature-card">
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
  background:
    radial-gradient(ellipse 60% 40% at 85% 0%, rgba(99, 102, 241, 0.08), transparent 70%),
    var(--md-bg);
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
  border-radius: var(--md-radius);
  border: 1px solid var(--md-border);
  background: var(--md-card);
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
  background: radial-gradient(320px circle at var(--glow-x, 50%) 0%, rgba(139, 92, 246, 0.1), transparent 70%);
  opacity: 0;
  transition: opacity 0.35s ease;
}

.feature-card:hover {
  transform: translateY(-6px);
  border-color: rgba(139, 92, 246, 0.4);
  box-shadow: 0 16px 40px rgba(5, 6, 10, 0.5);
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
  border-radius: 12px;
  color: #c7caff;
  background: linear-gradient(135deg, rgba(99, 102, 241, 0.22), rgba(168, 85, 247, 0.22));
  border: 1px solid rgba(139, 92, 246, 0.3);
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
  }
}
</style>
