<script setup>
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'

const stageRef = ref(null)
const screenRefs = ref([])

const screens = [
  { name: '屏幕 1', keys: ['⌘', '⌥', '1'] },
  { name: '屏幕 2', keys: ['⌘', '⌥', '2'] },
]

const current = ref(0)
const flying = ref(false)
const active = ref(false)
const rippleKey = ref(0)
const pos = ref({ x: 0, y: 0 })
const fromX = ref(0)

const direction = computed(() => (pos.value.x >= fromX.value ? 'right' : 'left'))

let resizeObserver
let io
let flyTimer

const measure = () => {
  const stage = stageRef.value
  const el = screenRefs.value[current.value]
  if (!stage || !el) return
  const s = stage.getBoundingClientRect()
  const r = el.getBoundingClientRect()
  pos.value = {
    x: r.left - s.left + r.width / 2,
    y: r.top - s.top + r.height / 2,
  }
}

const jumpTo = (index) => {
  if (index === current.value || flying.value) return
  fromX.value = pos.value.x
  current.value = index
  flying.value = true
  measure()
  clearTimeout(flyTimer)
  flyTimer = setTimeout(() => {
    flying.value = false
    rippleKey.value += 1
  }, 620)
}

// 双击 Command：在当前屏幕与上一个活跃屏幕之间来回切换
const toggleScreen = () => {
  jumpTo(current.value === 0 ? 1 : 0)
}

let lastMetaTime = 0

const onKeydown = (e) => {
  if (!active.value) return
  if (e.key === 'Meta') {
    const now = Date.now()
    if (now - lastMetaTime < 400) toggleScreen()
    lastMetaTime = now
    return
  }
  if (e.metaKey || e.ctrlKey || e.altKey) return
  const index = ['1', '2'].indexOf(e.key)
  if (index !== -1) jumpTo(index)
}

onMounted(() => {
  measure()
  resizeObserver = new ResizeObserver(measure)
  resizeObserver.observe(stageRef.value)
  io = new IntersectionObserver(
    (entries) => {
      active.value = entries[0].isIntersecting
    },
    { threshold: 0.4 },
  )
  io.observe(stageRef.value)
  window.addEventListener('keydown', onKeydown)
})

onBeforeUnmount(() => {
  resizeObserver?.disconnect()
  io?.disconnect()
  window.removeEventListener('keydown', onKeydown)
  clearTimeout(flyTimer)
})
</script>

<template>
  <section class="md-section demo" id="demo">
    <div class="md-container">
      <span class="md-section-tag">核心玩法</span>
      <h2 class="md-section-title">一键，鼠标<span class="md-gradient-text">跳屏</span></h2>
      <p class="md-section-desc">
        点击快捷键徽章，或在演示区可见时直接按下键盘
        <kbd class="demo-inline-kbd">1</kbd> / <kbd class="demo-inline-kbd">2</kbd> 跳屏，
        快速双击 <kbd class="demo-inline-kbd">⌘</kbd> Command 则在两块屏幕之间来回切换。
      </p>

      <div ref="stageRef" class="demo-stage">
        <div
          v-for="(screen, i) in screens"
          :key="screen.name"
          :ref="(el) => (screenRefs[i] = el)"
          class="demo-screen"
          :class="{ 'demo-screen--active': current === i }"
        >
          <div class="demo-menubar">
            <span class="demo-menubar-apple"></span>
            <span class="demo-menubar-icon"></span>
          </div>
          <span class="demo-screen-name">{{ screen.name }}</span>
        </div>

        <div
          class="demo-cursor"
          :class="[`demo-cursor--${direction}`, { 'demo-cursor--flying': flying }]"
          :style="{ transform: `translate(${pos.x}px, ${pos.y}px)` }"
        >
          <div class="demo-cursor-inner">
            <span class="demo-speed demo-speed--1"></span>
            <span class="demo-speed demo-speed--2"></span>
            <span class="demo-speed demo-speed--3"></span>
            <svg width="26" height="26" viewBox="0 0 24 24" fill="none">
              <path
                d="M5 3l6.5 17 2-7.2 7.2-2L5 3z"
                fill="#fff"
                stroke="#0b0d14"
                stroke-width="1.2"
                stroke-linejoin="round"
              />
            </svg>
          </div>
        </div>

        <div
          v-for="n in 1"
          :key="rippleKey"
          class="demo-ripple"
          :style="{ left: pos.x + 'px', top: pos.y + 'px' }"
        ></div>
      </div>

      <div class="demo-controls">
        <button
          v-for="(screen, i) in screens"
          :key="screen.name"
          class="demo-key"
          :class="{ 'demo-key--active': current === i }"
          @click="jumpTo(i)"
        >
          <kbd v-for="k in screen.keys" :key="k">{{ k }}</kbd>
          <span>{{ screen.name }}</span>
        </button>
        <button class="demo-key demo-key--toggle" @click="toggleScreen">
          <kbd>⌘</kbd><kbd>⌘</kbd>
          <span>双击·来回切换</span>
        </button>
        <span class="demo-status">鼠标当前在 {{ screens[current].name }}</span>
      </div>
    </div>
  </section>
</template>

<style scoped>
.demo {
  background:
    radial-gradient(ellipse 55% 45% at 15% 100%, rgba(168, 85, 247, 0.08), transparent 70%),
    var(--md-bg);
}

.demo-inline-kbd {
  padding: 1px 7px;
  border-radius: 5px;
  border: 1px solid var(--md-border-strong);
  background: rgba(255, 255, 255, 0.05);
  font-family: var(--md-font-mono);
  font-size: 13px;
}

.demo-stage {
  position: relative;
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 24px;
  margin-top: 48px;
  padding: 36px;
  border-radius: 20px;
  border: 1px solid var(--md-border);
  background:
    radial-gradient(ellipse 70% 60% at 50% 0%, rgba(99, 102, 241, 0.07), transparent 70%),
    #0d101a;
  overflow: hidden;
}

.demo-screen {
  position: relative;
  aspect-ratio: 16 / 10;
  border-radius: 12px;
  border: 1px solid var(--md-border-strong);
  background:
    radial-gradient(ellipse 90% 80% at 30% 20%, rgba(99, 102, 241, 0.16), transparent 60%),
    radial-gradient(ellipse 80% 70% at 80% 90%, rgba(168, 85, 247, 0.12), transparent 60%),
    #10131f;
  display: flex;
  align-items: center;
  justify-content: center;
  transition:
    border-color 0.35s ease,
    box-shadow 0.35s ease;
}

.demo-screen--active {
  border-color: rgba(139, 92, 246, 0.55);
  box-shadow:
    0 0 0 1px rgba(139, 92, 246, 0.3),
    0 0 40px rgba(139, 92, 246, 0.18);
}

.demo-menubar {
  position: absolute;
  inset: 0 0 auto 0;
  height: 18px;
  border-bottom: 1px solid var(--md-border);
  background: rgba(255, 255, 255, 0.03);
  border-radius: 12px 12px 0 0;
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0 10px;
}

.demo-menubar-apple {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  background: rgba(255, 255, 255, 0.25);
}

.demo-menubar-icon {
  width: 8px;
  height: 8px;
  border-radius: 2px;
  background: linear-gradient(135deg, #6366f1, #a855f7);
}

.demo-screen-name {
  font-size: 14px;
  color: var(--md-text-faint);
  font-family: var(--md-font-display);
}

.demo-cursor {
  position: absolute;
  left: 0;
  top: 0;
  z-index: 3;
  transition: transform 0.6s cubic-bezier(0.5, 0, 0.3, 1);
  will-change: transform;
}

.demo-cursor-inner {
  position: relative;
  transform: translate(-30%, -30%);
  filter: drop-shadow(0 4px 12px rgba(0, 0, 0, 0.5));
}

.demo-cursor--flying .demo-cursor-inner {
  animation: demo-arc 0.6s cubic-bezier(0.5, 0, 0.3, 1);
}

@keyframes demo-arc {
  0% {
    transform: translate(-30%, -30%) scale(1);
  }
  45% {
    transform: translate(-30%, calc(-30% - 72px)) scale(0.92);
  }
  100% {
    transform: translate(-30%, -30%) scale(1);
  }
}

.demo-speed {
  position: absolute;
  top: 8px;
  height: 3px;
  border-radius: 2px;
  background: linear-gradient(90deg, transparent, #c7caff);
  opacity: 0;
}

.demo-speed--1 {
  width: 34px;
}

.demo-speed--2 {
  width: 24px;
  top: 15px;
}

.demo-speed--3 {
  width: 16px;
  top: 22px;
}

.demo-cursor--right .demo-speed {
  right: 100%;
  margin-right: 4px;
}

.demo-cursor--left .demo-speed {
  left: 100%;
  margin-left: 4px;
  transform: scaleX(-1);
}

.demo-cursor--flying .demo-speed {
  animation: demo-trail 0.6s ease-out;
}

@keyframes demo-trail {
  0%,
  55% {
    opacity: 1;
  }
  100% {
    opacity: 0;
  }
}

.demo-ripple {
  position: absolute;
  z-index: 2;
  width: 12px;
  height: 12px;
  margin: -6px 0 0 -6px;
  border-radius: 50%;
  border: 2px solid rgba(192, 132, 252, 0.9);
  animation: demo-ping 0.9s cubic-bezier(0, 0, 0.2, 1) both;
  pointer-events: none;
}

@keyframes demo-ping {
  0% {
    transform: scale(1);
    opacity: 1;
  }
  100% {
    transform: scale(5);
    opacity: 0;
  }
}

.demo-controls {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 16px;
  margin-top: 26px;
}

.demo-key {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  padding: 10px 18px;
  border-radius: 12px;
  border: 1px solid var(--md-border);
  background: var(--md-card);
  color: var(--md-text-dim);
  font-size: 14px;
  font-family: var(--md-font-body);
  cursor: pointer;
  transition:
    border-color 0.25s ease,
    color 0.25s ease,
    transform 0.25s ease;
}

.demo-key:hover {
  transform: translateY(-2px);
}

.demo-key--active {
  border-color: rgba(139, 92, 246, 0.55);
  color: var(--md-text);
  box-shadow: 0 0 20px rgba(139, 92, 246, 0.15);
}

.demo-key--toggle {
  border-color: rgba(99, 102, 241, 0.45);
  background: linear-gradient(135deg, rgba(99, 102, 241, 0.14), rgba(168, 85, 247, 0.14));
  color: var(--md-text);
}

.demo-key kbd {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-width: 26px;
  height: 26px;
  padding: 0 6px;
  border-radius: 6px;
  border: 1px solid var(--md-border-strong);
  border-bottom-width: 2px;
  background: rgba(255, 255, 255, 0.05);
  font-family: var(--md-font-mono);
  font-size: 13px;
  color: var(--md-text);
}

.demo-status {
  margin-left: auto;
  font-size: 13px;
  color: var(--md-text-faint);
}

@media (max-width: 640px) {
  .demo-stage {
    gap: 14px;
    padding: 18px;
  }

  .demo-status {
    width: 100%;
    margin-left: 0;
  }
}
</style>
