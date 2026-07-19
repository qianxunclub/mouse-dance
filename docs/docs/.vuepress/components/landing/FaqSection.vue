<script setup>
import { ref } from 'vue'

const faqs = [
  {
    q: '为什么首次打开提示"应用已损坏，无法打开"？',
    a: 'MouseDance 未使用 Apple 开发者证书签名，macOS Gatekeeper 会对未签名应用给出该提示。下载后在终端执行 xattr -cr /Applications/MouseDance.app 解除隔离即可正常打开。',
  },
  {
    q: '需要授予哪些系统权限？',
    a: '仅需要"输入监控"权限，用于监听全局快捷键。首次启动后点击主窗口中的"前往授权…"，在系统设置中勾选 MouseDance；若已存在，请关闭后重新打开开关。',
  },
  {
    q: '最多支持几块显示器？',
    a: 'MouseDance 会自动识别当前接入的所有显示器，主窗口会显示"当前识别 N 块屏幕"，每一块都可以单独录制快捷键，数量不受限制。',
  },
  {
    q: '什么是"双击修饰键"？',
    a: '除了常规组合键，你还可以把快捷键录成"双击 Command / Control / Option"。录入时直接快速双击对应修饰键即可，轻量且不易与其他软件冲突。',
  },
  {
    q: '如何卸载 MouseDance？',
    a: '先通过菜单栏图标退出 MouseDance，然后将 /Applications/MouseDance.app 移入废纸篓即可，无残留文件。',
  },
]

const openIndex = ref(0)

const toggle = (index) => {
  openIndex.value = openIndex.value === index ? -1 : index
}
</script>

<template>
  <section class="md-section faq" id="faq">
    <div class="md-container faq-container">
      <span class="md-section-tag">常见问题</span>
      <h2 class="md-section-title">还有<span class="md-gradient-text">疑问</span>？</h2>

      <div class="faq-list">
        <div v-for="(faq, i) in faqs" :key="faq.q" class="faq-item" :class="{ 'faq-item--open': openIndex === i }">
          <button class="faq-question" :aria-expanded="openIndex === i" @click="toggle(i)">
            <span>{{ faq.q }}</span>
            <svg class="faq-chevron" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
              <polyline points="6 9 12 15 18 9" />
            </svg>
          </button>
          <div class="faq-answer">
            <p class="faq-answer-text">{{ faq.a }}</p>
          </div>
        </div>
      </div>
    </div>
  </section>
</template>

<style scoped>
.faq {
  background: var(--md-bg);
}

.faq-container {
  max-width: 780px;
}

.faq-list {
  display: flex;
  flex-direction: column;
  gap: 12px;
  margin-top: 44px;
}

.faq-item {
  border: 1px solid var(--md-border);
  border-radius: var(--md-radius);
  background: var(--md-card);
  transition: border-color 0.3s ease;
}

.faq-item--open {
  border-color: rgba(139, 92, 246, 0.4);
}

.faq-question {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
  width: 100%;
  padding: 20px 24px;
  border: none;
  background: none;
  color: var(--md-text);
  font-size: 15px;
  font-weight: 600;
  font-family: var(--md-font-body);
  text-align: left;
  cursor: pointer;
}

.faq-chevron {
  flex-shrink: 0;
  color: var(--md-text-faint);
  transition: transform 0.35s cubic-bezier(0.22, 1, 0.36, 1);
}

.faq-item--open .faq-chevron {
  transform: rotate(180deg);
  color: var(--md-accent-2);
}

.faq-answer {
  display: grid;
  grid-template-rows: 0fr;
  transition: grid-template-rows 0.4s cubic-bezier(0.22, 1, 0.36, 1);
}

.faq-item--open .faq-answer {
  grid-template-rows: 1fr;
}

.faq-answer-text {
  overflow: hidden;
  margin: 0;
  padding: 0 24px;
  font-size: 14px;
  line-height: 1.8;
  color: var(--md-text-dim);
  transition: padding 0.3s ease;
}

.faq-item--open .faq-answer-text {
  padding-bottom: 22px;
}
</style>
