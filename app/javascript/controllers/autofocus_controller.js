import { Controller } from "@hotwired/stimulus"

// Focuses the target input on connect (covers Turbo navigations where the
// autofocus HTML attribute is unreliable). Used by the /search input.
export default class extends Controller {
  static targets = ["input"]

  connect() {
    if (this.hasInputTarget) {
      requestAnimationFrame(() => this.inputTarget.focus())
    }
  }
}
