<script setup>
import { onMounted, ref } from 'vue'

const props = defineProps({
  compact: { type: Boolean, default: false },
})

const githubStars = ref(null)
const giteeStars = ref(null)

const CACHE_KEY = 'md-star-counts'
const CACHE_TTL = 30 * 60 * 1000 // 30 minutes

function getCached() {
  try {
    const raw = sessionStorage.getItem(CACHE_KEY)
    if (!raw) return null
    const data = JSON.parse(raw)
    if (Date.now() - data.ts < CACHE_TTL) return data
  } catch { /* ignore */ }
  return null
}

function setCache(github, gitee) {
  try {
    sessionStorage.setItem(CACHE_KEY, JSON.stringify({
      ts: Date.now(),
      github,
      gitee,
    }))
  } catch { /* ignore */ }
}

async function fetchGithubStars() {
  try {
    const res = await fetch('https://api.github.com/repos/qianxunclub/mouse-dance')
    if (!res.ok) return
    const data = await res.json()
    githubStars.value = data.stargazers_count ?? 0
  } catch { /* ignore */ }
}

async function fetchGiteeStars() {
  try {
    const res = await fetch('https://gitee.com/api/v5/repos/qianxunclub/mouse-dance')
    if (!res.ok) return
    const data = await res.json()
    giteeStars.value = data.stargazers_count ?? 0
  } catch { /* ignore */ }
}

function formatCount(n) {
  if (n === null) return '--'
  if (n >= 1000) return (n / 1000).toFixed(1).replace(/\.0$/, '') + 'k'
  return String(n)
}

onMounted(async () => {
  const cached = getCached()
  if (cached) {
    githubStars.value = cached.github
    giteeStars.value = cached.gitee
    return
  }
  await Promise.all([fetchGithubStars(), fetchGiteeStars()])
  setCache(githubStars.value, giteeStars.value)
})
</script>

<template>
  <div class="star-buttons" :class="{ 'star-buttons--compact': compact }">
    <a
      class="star-btn star-btn--github"
      href="https://github.com/qianxunclub/mouse-dance"
      target="_blank"
      rel="noopener"
      title="Star on GitHub"
    >
      <svg class="star-btn-icon" viewBox="0 0 24 24" fill="none" aria-hidden="true">
        <path fill="currentColor" d="M12 2C6.475 2 2 6.475 2 12a9.994 9.994 0 0 0 6.838 9.488c.5.087.687-.213.687-.476 0-.237-.013-1.024-.013-1.862-2.512.463-3.162-.612-3.362-1.175-.113-.288-.6-1.175-1.025-1.413-.35-.187-.85-.65-.013-.662.788-.013 1.35.725 1.538 1.025.9 1.512 2.338 1.087 2.912.825.088-.65.35-1.087.638-1.337-2.225-.25-4.55-1.113-4.55-4.938 0-1.088.387-1.987 1.025-2.688-.1-.25-.45-1.275.1-2.65 0 0 .837-.262 2.75 1.026a9.28 9.28 0 0 1 2.5-.338c.85 0 1.7.112 2.5.337 1.912-1.3 2.75-1.024 2.75-1.024.55 1.375.2 2.4.1 2.65.637.7 1.025 1.587 1.025 2.687 0 3.838-2.337 4.688-4.562 4.938.362.312.675.912.675 1.85 0 1.337-.013 2.412-.013 2.75 0 .262.188.574.688.474A10.016 10.016 0 0 0 22 12c0-5.525-4.475-10-10-10z"/>
      </svg>
      <span class="star-btn-label" v-if="!compact">GitHub</span>
      <span class="star-btn-count">{{ formatCount(githubStars) }}</span>
    </a>

    <a
      class="star-btn star-btn--gitee"
      href="https://gitee.com/qianxunclub/mouse-dance"
      target="_blank"
      rel="noopener"
      title="Star on Gitee"
    >
      <svg class="star-btn-icon" viewBox="0 0 24 24" fill="none" aria-hidden="true">
        <path fill="currentColor" d="M11.984 0C5.337 0 0 5.402 0 12c0 5.302 3.438 9.8 8.207 11.387.599.112.793-.262.793-.581 0-.288-.012-1.05-.019-2.062-3.337.727-4.043-1.612-4.043-1.612-.544-1.394-1.332-1.765-1.332-1.765-1.09-.747.082-.732.082-.732 1.204.085 1.839 1.244 1.839 1.244 1.07 1.842 2.806 1.311 3.491 1.002.108-.78.419-1.312.762-1.613-2.666-.305-5.467-1.339-5.467-5.96 0-1.317.469-2.395 1.237-3.24-.124-.306-.536-1.532.117-3.194 0 0 1.008-.324 3.3 1.236a11.487 11.487 0 0 1 3.003-.406 11.49 11.49 0 0 1 3.003.406c2.29-1.56 3.297-1.236 3.297-1.236.655 1.662.243 2.888.119 3.194.77.845 1.235 1.923 1.235 3.24 0 4.636-2.806 5.652-5.477 5.95.431.373.814 1.105.814 2.225 0 1.607-.014 2.902-.014 3.298 0 .322.19.698.8.58C20.565 21.792 24 17.298 24 12c0-6.598-5.337-12-12.016-12z"/>
      </svg>
      <span class="star-btn-label" v-if="!compact">Gitee</span>
      <span class="star-btn-count">{{ formatCount(giteeStars) }}</span>
    </a>
  </div>
</template>

<style scoped>
.star-buttons {
  display: inline-flex;
  align-items: center;
  gap: 8px;
}

.star-btn {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  height: 36px;
  padding: 0 14px;
  border-radius: 999px;
  border: 1px solid var(--md-border);
  background: rgba(255, 255, 255, 0.04);
  font-size: 13px;
  font-weight: 500;
  color: var(--md-text-dim);
  transition:
    color 0.25s ease,
    background 0.25s ease,
    border-color 0.25s ease,
    transform 0.25s ease;
}

.star-btn:hover {
  color: var(--md-text);
  background: rgba(255, 255, 255, 0.08);
  border-color: var(--md-border-strong);
  transform: translateY(-1px);
}

.star-btn--github:hover {
  border-color: rgba(255, 255, 255, 0.25);
}

.star-btn--gitee:hover {
  border-color: #c71d23;
}

.star-btn-icon {
  width: 16px;
  height: 16px;
  flex-shrink: 0;
}

.star-btn-label {
  font-size: 13px;
}

.star-btn-count {
  font-variant-numeric: tabular-nums;
  color: var(--md-text-faint);
  min-width: 24px;
  text-align: center;
}

/* compact mode */
.star-buttons--compact .star-btn {
  height: 32px;
  padding: 0 10px;
  font-size: 12px;
}

.star-buttons--compact .star-btn-icon {
  width: 14px;
  height: 14px;
}

.star-buttons--compact .star-btn-count {
  font-size: 12px;
  min-width: 20px;
}
</style>
