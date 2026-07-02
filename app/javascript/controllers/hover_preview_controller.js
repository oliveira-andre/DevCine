import { Controller } from "@hotwired/stimulus"

// Plays a card's muted preview clip only after the pointer has hovered for
// more than the configured delay (default 2000ms). On leave it stops and
// reverts to the poster. No-op when the card has no preview <video> (FR-028).
export default class extends Controller {
  static targets = ["video"]
  static values = { delay: { type: Number, default: 2000 } }

  start() {
    if (!this.hasVideoTarget) return
    this.timer = setTimeout(() => this.play(), this.delayValue)
  }

  stop() {
    clearTimeout(this.timer)
    if (!this.hasVideoTarget) return
    const video = this.videoTarget
    video.pause()
    video.currentTime = 0
    this.element.classList.remove("is-previewing")
  }

  play() {
    const video = this.videoTarget
    if (!video.src) video.src = video.dataset.src
    this.element.classList.add("is-previewing")
    video.play().catch(() => {})
  }

  disconnect() {
    clearTimeout(this.timer)
  }
}
