import { Controller } from "@hotwired/stimulus"

// Opens a full-screen search overlay on mobile; the inline compact field is
// used on desktop (CSS breakpoints handle which trigger/field is visible).
export default class extends Controller {
  static targets = ["overlay", "field"]

  open() {
    this.overlayTarget.dataset.open = "true"
    if (this.hasFieldTarget) this.fieldTarget.focus()
  }

  close() {
    this.overlayTarget.dataset.open = "false"
  }
}
