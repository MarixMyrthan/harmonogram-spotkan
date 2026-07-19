import { useEffect, useRef } from 'react'

interface MatrixRainProps {
  active: boolean
  onFinish: () => void
}

const SYMBOLS = 'アァカサタナハマヤャラワ0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ'
const DURATION_MS = 14_000

export function MatrixRain({ active, onFinish }: MatrixRainProps) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null)

  useEffect(() => {
    if (!active) return
    const canvas = canvasRef.current
    if (!canvas) return
    const context = canvas.getContext('2d')
    if (!context) return

    let animationFrame = 0
    let columns: number[] = []
    const fontSize = 18

    const resize = () => {
      const ratio = Math.max(1, window.devicePixelRatio || 1)
      canvas.width = Math.floor(window.innerWidth * ratio)
      canvas.height = Math.floor(window.innerHeight * ratio)
      canvas.style.width = `${window.innerWidth}px`
      canvas.style.height = `${window.innerHeight}px`
      context.setTransform(ratio, 0, 0, ratio, 0, 0)
      columns = Array.from({ length: Math.ceil(window.innerWidth / fontSize) }, () => Math.random() * -80)
    }

    resize()
    window.addEventListener('resize', resize)

    const startedAt = performance.now()
    let lastFrame = 0
    const draw = (time: number) => {
      if (time - startedAt >= DURATION_MS) {
        onFinish()
        return
      }
      if (time - lastFrame >= 50) {
        lastFrame = time
        context.fillStyle = 'rgba(0, 0, 0, 0.12)'
        context.fillRect(0, 0, window.innerWidth, window.innerHeight)
        context.font = `${fontSize}px ui-monospace, SFMono-Regular, Consolas, monospace`

        columns.forEach((drop, index) => {
          const character = SYMBOLS[Math.floor(Math.random() * SYMBOLS.length)]
          context.fillStyle = Math.random() > 0.96 ? '#d9ffe6' : '#20ff6b'
          context.fillText(character, index * fontSize, drop * fontSize)
          columns[index] = drop * fontSize > window.innerHeight && Math.random() > 0.975
            ? Math.random() * -20
            : drop + 1
        })
      }
      animationFrame = window.requestAnimationFrame(draw)
    }

    context.fillStyle = '#000'
    context.fillRect(0, 0, window.innerWidth, window.innerHeight)
    animationFrame = window.requestAnimationFrame(draw)

    const stopOnEscape = (event: globalThis.KeyboardEvent) => {
      if (event.key === 'Escape') onFinish()
    }
    window.addEventListener('keydown', stopOnEscape)

    return () => {
      window.cancelAnimationFrame(animationFrame)
      window.removeEventListener('resize', resize)
      window.removeEventListener('keydown', stopOnEscape)
    }
  }, [active, onFinish])

  if (!active) return null
  return <canvas className="matrix-rain" ref={canvasRef} aria-hidden="true" />
}
