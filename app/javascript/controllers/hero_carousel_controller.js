import { Controller } from "@hotwired/stimulus"

// Cycles the hero slides on an interval, pausing on hover (DESIGN §5.2).
export default class extends Controller {
  static targets = ["slide"]
  static values = { interval: { type: Number, default: 8000 } }

  connect() {
    this.index = 0
    if (this.slideTargets.length > 1) this.resume()
  }

  resume() {
    this.stop()
    this.timer = setInterval(() => this.next(), this.intervalValue)
  }

  pause() {
    this.stop()
  }

  next() {
    if (this.slideTargets.length < 2) return
    this.slideTargets[this.index].classList.remove("is-active")
    this.index = (this.index + 1) % this.slideTargets.length
    this.slideTargets[this.index].classList.add("is-active")
  }

  stop() {
    if (this.timer) clearInterval(this.timer)
  }

  disconnect() {
    this.stop()
  }
}
