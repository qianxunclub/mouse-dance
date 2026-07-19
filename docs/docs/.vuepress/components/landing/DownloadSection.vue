<script setup>
import { ref } from 'vue'

const command = 'xattr -cr /Applications/MouseDance.app'
const copied = ref(false)

const copyCommand = async () => {
  try {
    await navigator.clipboard.writeText(command)
  } catch {
    const textarea = document.createElement('textarea')
    textarea.value = command
    document.body.appendChild(textarea)
    textarea.select()
    document.execCommand('copy')
    document.body.removeChild(textarea)
  }
  copied.value = true
  setTimeout(() => (copied.value = false), 1800)
}

const steps = [
  {
    title: '拖入应用程序',
    desc: '下载并打开 MouseDance.dmg，将 MouseDance.app 拖入"应用程序"文件夹。',
  },
  {
    title: '解除 Gatekeeper 隔离',
    desc: '应用未使用 Apple 开发者证书签名，首次打开前在终端执行右侧命令（一键复制）。',
  },
  {
    title: '打开并授权',
    desc: '双击打开 MouseDance，按指引授予"输入监控"权限，图标将出现在菜单栏。',
  },
]
</script>

<template>
  <section class="md-section download" id="download">
    <div class="md-container">
      <div class="download-panel">
        <div class="download-glow" aria-hidden="true"></div>

        <span class="md-section-tag">下载安装</span>
        <h2 class="md-section-title">三步，开始<span class="md-gradient-text">起舞</span></h2>
        <p class="download-hint">
          本应用未签名，首次打开 macOS 可能提示"应用已损坏"或"无法验证开发者"——属正常现象，按下方步骤处理即可。
        </p>

        <a
          class="md-btn md-btn-primary download-cta"
          href="https://gitee.com/qianxunclub/mouse-dance/releases"
          target="_blank"
          rel="noopener"
        >
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4" />
            <polyline points="7 10 12 15 17 10" />
            <line x1="12" y1="15" x2="12" y2="3" />
          </svg>
          下载 MouseDance（dmg）
        </a>

        <div class="download-steps">
          <div v-for="(step, i) in steps" :key="step.title" class="download-step">
            <span class="download-step-num">{{ i + 1 }}</span>
            <div>
              <h3 class="download-step-title">{{ step.title }}</h3>
              <p class="download-step-desc">{{ step.desc }}</p>
            </div>
          </div>
        </div>

        <div class="download-command">
          <code>{{ command }}</code>
          <button class="download-copy" @click="copyCommand">
            <svg v-if="!copied" width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
              <rect x="9" y="9" width="13" height="13" rx="2" />
              <path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1" />
            </svg>
            <svg v-else width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
              <polyline points="20 6 9 17 4 12" />
            </svg>
            {{ copied ? '已复制' : '复制' }}
          </button>
        </div>
      </div>
    </div>
  </section>
</template>

<style scoped>
.download {
  background:
    radial-gradient(ellipse 60% 50% at 50% 100%, rgba(99, 102, 241, 0.1), transparent 70%),
    var(--md-bg);
}

.download-panel {
  position: relative;
  padding: 56px clamp(24px, 6vw, 72px);
  border-radius: 24px;
  border: 1px solid var(--md-border);
  background: linear-gradient(180deg, rgba(20, 24, 36, 0.9), rgba(13, 16, 26, 0.9));
  overflow: hidden;
}

.download-glow {
  position: absolute;
  top: -160px;
  right: -120px;
  width: 420px;
  height: 420px;
  border-radius: 50%;
  background: radial-gradient(circle, rgba(139, 92, 246, 0.22), transparent 65%);
  filter: blur(70px);
  pointer-events: none;
}

.download-hint {
  margin: 16px 0 0;
  max-width: 640px;
  font-size: 14px;
  line-height: 1.7;
  color: var(--md-text-faint);
}

.download-cta {
  margin-top: 30px;
}

.download-steps {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 20px;
  margin-top: 44px;
}

.download-step {
  display: flex;
  gap: 14px;
  padding: 20px;
  border-radius: var(--md-radius);
  border: 1px solid var(--md-border);
  background: rgba(255, 255, 255, 0.02);
}

.download-step-num {
  flex-shrink: 0;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 28px;
  height: 28px;
  border-radius: 9px;
  background: var(--md-gradient);
  color: #fff;
  font-size: 14px;
  font-weight: 700;
  font-family: var(--md-font-display);
}

.download-step-title {
  margin: 2px 0 0;
  font-size: 15px;
  font-weight: 600;
}

.download-step-desc {
  margin: 8px 0 0;
  font-size: 13px;
  line-height: 1.7;
  color: var(--md-text-dim);
}

.download-command {
  display: flex;
  align-items: center;
  gap: 12px;
  margin-top: 24px;
  padding: 14px 18px;
  border-radius: 12px;
  border: 1px solid var(--md-border);
  background: #080a10;
}

.download-command code {
  flex: 1;
  font-family: var(--md-font-mono);
  font-size: 14px;
  color: #c7caff;
  overflow-x: auto;
  white-space: nowrap;
}

.download-copy {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 7px 14px;
  border-radius: 8px;
  border: 1px solid var(--md-border-strong);
  background: rgba(255, 255, 255, 0.05);
  color: var(--md-text-dim);
  font-size: 13px;
  font-family: var(--md-font-body);
  cursor: pointer;
  transition:
    color 0.25s ease,
    background 0.25s ease;
}

.download-copy:hover {
  color: var(--md-text);
  background: rgba(255, 255, 255, 0.1);
}

@media (max-width: 860px) {
  .download-steps {
    grid-template-columns: 1fr;
  }
}
</style>
