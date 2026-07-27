<script setup>
import { onBeforeUnmount, onMounted, ref } from 'vue'
import { isReducedMotion, makeMagnetic, useGsapScope } from '../../composables/useGsap'

const rootRef = ref(null)
let cleanupMagnetic

useGsapScope(() => rootRef.value, (gsap) => {
  gsap.from('.download-panel', {
    autoAlpha: 0,
    y: 64,
    duration: 0.95,
    ease: 'power3.out',
    scrollTrigger: { trigger: '.download-panel', start: 'top 84%', once: true },
  })
  gsap.from('.download-step', {
    autoAlpha: 0,
    y: 32,
    duration: 0.7,
    stagger: 0.12,
    ease: 'power3.out',
    scrollTrigger: { trigger: '.download-steps', start: 'top 88%', once: true },
  })
  gsap.from('.download-command', {
    autoAlpha: 0,
    y: 24,
    duration: 0.7,
    ease: 'power3.out',
    scrollTrigger: { trigger: '.download-command', start: 'top 92%', once: true },
  })
})

onMounted(() => {
  if (isReducedMotion() || !rootRef.value) return
  cleanupMagnetic = makeMagnetic(rootRef.value.querySelector('.download-cta-magnet'), 0.3)
})

onBeforeUnmount(() => {
  cleanupMagnetic?.()
})

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
    desc: '应用未使用 Apple 开发者证书签名，首次打开前在终端执行下方命令（一键复制）。',
  },
  {
    title: '打开并授权',
    desc: '双击打开 MouseDance，按指引授予"输入监控"权限，图标将出现在菜单栏。',
  },
]
</script>

<template>
  <section class="md-section download" id="download" ref="rootRef">
    <div class="md-container">
      <div class="download-panel">
        <div class="download-glow" aria-hidden="true"></div>

        <span class="md-section-tag">下载安装</span>
        <h2 class="md-section-title">三步，开始<span class="md-gradient-text">起舞</span></h2>
        <p class="download-hint">
          本应用未签名，首次打开 macOS 可能提示"应用已损坏"或"无法验证开发者"——属正常现象，按下方步骤处理即可。
        </p>

        <span class="download-cta-magnet">
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
        </span>

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
  background: radial-gradient(ellipse 60% 50% at 50% 100%, rgba(10, 132, 255, 0.12), transparent 70%);
}

.download-panel {
  position: relative;
  padding: 56px clamp(24px, 6vw, 72px);
  border-radius: 28px;
  border: 1px solid var(--md-glass-border);
  background: linear-gradient(165deg, rgba(255, 255, 255, 0.1), rgba(255, 255, 255, 0.03) 45%, rgba(255, 255, 255, 0.015));
  -webkit-backdrop-filter: blur(26px) saturate(180%);
  backdrop-filter: blur(26px) saturate(180%);
  box-shadow:
    inset 0 1px 0 rgba(255, 255, 255, 0.26),
    inset 0 -1px 0 rgba(255, 255, 255, 0.05),
    0 30px 80px rgba(3, 5, 12, 0.55);
  overflow: hidden;
}

.download-glow {
  position: absolute;
  top: -160px;
  right: -120px;
  width: 420px;
  height: 420px;
  border-radius: 50%;
  background: radial-gradient(circle, rgba(100, 210, 255, 0.2), transparent 65%);
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

.download-cta-magnet {
  display: inline-flex;
  min-width: 0;
  max-width: 100%;
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
  border: 1px solid rgba(255, 255, 255, 0.12);
  background: linear-gradient(165deg, rgba(255, 255, 255, 0.07), rgba(255, 255, 255, 0.02));
  box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.16);
  min-width: 0;
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
  min-width: 0;
  overflow-wrap: break-word;
}

.download-command {
  display: flex;
  align-items: center;
  gap: 12px;
  margin-top: 24px;
  padding: 14px 18px;
  border-radius: 14px;
  border: 1px solid var(--md-glass-border);
  background: linear-gradient(165deg, rgba(255, 255, 255, 0.07), rgba(255, 255, 255, 0.02));
  box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.16);
  min-width: 0;
}

.download-command code {
  flex: 1;
  min-width: 0;
  font-family: var(--md-font-mono);
  font-size: 14px;
  color: #64d2ff;
  overflow-x: auto;
  white-space: nowrap;
}

.download-copy {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 7px 14px;
  border-radius: 9px;
  border: 1px solid var(--md-glass-border);
  background: linear-gradient(165deg, rgba(255, 255, 255, 0.12), rgba(255, 255, 255, 0.04));
  box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.2);
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
  background: linear-gradient(165deg, rgba(255, 255, 255, 0.18), rgba(255, 255, 255, 0.07));
}

@media (max-width: 860px) {
  .download-steps {
    grid-template-columns: 1fr;
  }
}

@media (max-width: 640px) {
  .download-panel {
    padding: 32px 16px;
    border-radius: 20px;
  }

  .download-hint {
    font-size: 13px;
  }

  .download-cta-magnet {
    display: block;
    width: 100%;
  }

  .download-cta {
    width: 100%;
    margin-top: 22px;
  }

  .download-steps {
    gap: 14px;
    margin-top: 32px;
  }

  .download-step {
    padding: 16px;
    border-radius: 14px;
  }

  .download-step-title {
    font-size: 14px;
  }

  .download-step-desc {
    font-size: 12px;
    margin-top: 6px;
  }

  .download-command {
    flex-direction: column;
    align-items: stretch;
    gap: 10px;
    padding: 12px 14px;
    border-radius: 12px;
  }

  .download-command code {
    font-size: 12px;
    white-space: normal;
    word-break: break-all;
  }

  .download-copy {
    align-self: flex-end;
  }

  .download-glow {
    width: 220px;
    height: 220px;
    top: -80px;
    right: -60px;
  }
}
</style>
