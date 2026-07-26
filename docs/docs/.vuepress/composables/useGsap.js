// GSAP 单例与落地页通用动效工具
import { gsap } from 'gsap'
import { ScrollTrigger } from 'gsap/ScrollTrigger'
import { onBeforeUnmount, onMounted } from 'vue'

let registered = false

export function useGsap() {
  if (!registered && typeof window !== 'undefined') {
    gsap.registerPlugin(ScrollTrigger)
    registered = true
  }
  return { gsap, ScrollTrigger }
}

export function isReducedMotion() {
  return typeof window !== 'undefined' && window.matchMedia('(prefers-reduced-motion: reduce)').matches
}

// 在组件作用域内创建 GSAP 动效，卸载时自动 revert
export function useGsapScope(getRoot, build) {
  let ctx
  onMounted(() => {
    if (isReducedMotion()) return
    const root = getRoot()
    if (!root) return
    const { gsap } = useGsap()
    ctx = gsap.context(() => build(gsap), root)
  })
  onBeforeUnmount(() => ctx?.revert())
}

// 区块头部（标签/标题/描述）统一滚动入场
export function revealSectionHeader(gsap) {
  gsap.from('.md-section-tag, .md-section-title, .md-section-desc', {
    autoAlpha: 0,
    y: 28,
    duration: 0.7,
    stagger: 0.1,
    ease: 'power3.out',
    scrollTrigger: { trigger: '.md-section-tag', start: 'top 86%', once: true },
  })
}

// 磁吸按钮：指针靠近时吸附跟随，离开后弹性回位
export function makeMagnetic(el, strength = 0.32) {
  if (!el) return () => {}
  const xTo = gsap.quickTo(el, 'x', { duration: 0.4, ease: 'power3' })
  const yTo = gsap.quickTo(el, 'y', { duration: 0.4, ease: 'power3' })

  const onMove = (e) => {
    const r = el.getBoundingClientRect()
    xTo((e.clientX - (r.left + r.width / 2)) * strength)
    yTo((e.clientY - (r.top + r.height / 2)) * strength)
  }
  const onLeave = () => {
    gsap.to(el, { x: 0, y: 0, duration: 0.8, ease: 'elastic.out(1, 0.35)' })
  }

  el.addEventListener('mousemove', onMove)
  el.addEventListener('mouseleave', onLeave)
  return () => {
    el.removeEventListener('mousemove', onMove)
    el.removeEventListener('mouseleave', onLeave)
  }
}
