import { Controller } from "@hotwired/stimulus"

// Flash toast: the ✕ removes it, and it fades out on its own so a banner
// floating over the page doesn't sit there covering content indefinitely.
const AUTO_DISMISS_MS = 6000
const LEAVE_MS = 200

export default class extends Controller {
  connect() {
    this.timer = setTimeout(() => this.dismiss(), AUTO_DISMISS_MS)
  }

  disconnect() {
    clearTimeout(this.timer)
    clearTimeout(this.leaveTimer)
  }

  dismiss() {
    clearTimeout(this.timer)
    this.element.classList.add("is-leaving")
    // Remove on a timer rather than transitionend: the transition never fires
    // under prefers-reduced-motion, which would strand the banner.
    this.leaveTimer = setTimeout(() => this.element.remove(), LEAVE_MS)
  }
}
