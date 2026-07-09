import { Controller } from "@hotwired/stimulus"

// Swaps a loading spinner for a lazy image once it loads; shows a placeholder
// on error. Handles images already cached/complete before connect.
export default class extends Controller {
  static targets = ["image", "spinner"]

  connect() {
    if (this.hasImageTarget && this.imageTarget.complete) {
      this.imageTarget.naturalWidth > 0 ? this.loaded() : this.failed()
    }
  }

  loaded() {
    this.element.classList.add("is-loaded")
  }

  failed() {
    this.element.classList.add("is-error")
  }
}
