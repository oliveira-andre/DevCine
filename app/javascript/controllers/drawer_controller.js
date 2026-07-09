import { Controller } from "@hotwired/stimulus"

// Left navigation drawer opened from the header avatar. Handles backdrop/close/
// Escape, a simple focus trap, and restoring focus on close.
export default class extends Controller {
  static targets = ["root", "panel", "backdrop"]

  open() {
    this.previouslyFocused = document.activeElement
    this.rootTarget.classList.add("is-open")
    document.body.classList.add("drawer-open")
    this.focusables()[0]?.focus()
  }

  close() {
    this.rootTarget.classList.remove("is-open")
    document.body.classList.remove("drawer-open")
    this.previouslyFocused?.focus()
  }

  keydown(event) {
    if (event.key === "Escape") {
      this.close()
    } else if (event.key === "Tab") {
      this.trapFocus(event)
    }
  }

  trapFocus(event) {
    const items = this.focusables()
    if (items.length === 0) return
    const first = items[0]
    const last = items[items.length - 1]
    if (event.shiftKey && document.activeElement === first) {
      event.preventDefault()
      last.focus()
    } else if (!event.shiftKey && document.activeElement === last) {
      event.preventDefault()
      first.focus()
    }
  }

  focusables() {
    return Array.from(
      this.panelTarget.querySelectorAll('a[href], button:not([disabled]), input')
    )
  }
}
