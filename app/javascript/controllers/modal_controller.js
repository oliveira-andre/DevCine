import { Controller } from "@hotwired/stimulus"

// Reusable modal: a <dialog> rendered into the shared "modal" Turbo frame.
// Opens on connect, closes on the close button / Escape / backdrop click, and
// clears the frame on close so it can be reopened. (Constitution I modal.)
export default class extends Controller {
  connect() {
    if (typeof this.element.showModal === "function" && !this.element.open) {
      this.element.showModal()
    }
    document.body.classList.add("modal-open")
  }

  disconnect() {
    document.body.classList.remove("modal-open")
  }

  close() {
    this.element.close()
  }

  // Clicking the dialog element itself (outside the panel) = backdrop click.
  backdrop(event) {
    if (event.target === this.element) this.element.close()
  }

  // Native "close" event (button/Escape/programmatic): empty the frame.
  onClose() {
    const frame = this.element.closest("turbo-frame")
    if (frame) {
      frame.removeAttribute("src")
      frame.innerHTML = ""
    }
  }
}
