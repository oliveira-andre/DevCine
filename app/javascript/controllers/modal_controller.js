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
  // The OUTERMOST modal frame, not closest(): a modal delivered by a Turbo
  // Stream update nests the helper's own frame inside the page's shared one,
  // and emptying only the inner copy would leave residue in the outer frame.
  onClose() {
    const frame = document.querySelector("turbo-frame#modal")
    if (frame) {
      frame.removeAttribute("src")
      frame.innerHTML = ""
    }
  }
}
