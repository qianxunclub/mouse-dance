<script setup>
import { withBase } from 'vuepress/client'
</script>

<template>
  <section class="md-section shot" id="screenshot">
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
  background: var(--md-bg);
}

.shot-frame {
  position: relative;
  margin-top: 52px;
}

.shot-glow {
  position: absolute;
  inset: -8% -12%;
  background:
    radial-gradient(ellipse 45% 55% at 30% 40%, rgba(99, 102, 241, 0.28), transparent 70%),
    radial-gradient(ellipse 40% 50% at 72% 60%, rgba(168, 85, 247, 0.22), transparent 70%);
  filter: blur(60px);
  pointer-events: none;
}

.shot-window {
  position: relative;
  border-radius: 14px;
  border: 1px solid var(--md-border-strong);
  background: #16181f;
  overflow: hidden;
  box-shadow:
    0 30px 80px rgba(3, 4, 8, 0.7),
    0 0 0 1px rgba(255, 255, 255, 0.04) inset;
}

.shot-titlebar {
  display: flex;
  align-items: center;
  gap: 8px;
  height: 38px;
  padding: 0 16px;
  border-bottom: 1px solid var(--md-border);
  background: rgba(255, 255, 255, 0.025);
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
