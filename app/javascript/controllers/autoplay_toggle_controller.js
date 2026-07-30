import { Controller } from "@hotwired/stimulus"

// Keeps the persistent mini-player's live autoplay flag in sync with the
// preference toggle (feature 010). Fires on initial render and after each
// turbo-stream replacement of the toggle.
export default class extends Controller {
  static values = { enabled: Boolean }

  connect() {
    document.dispatchEvent(new CustomEvent("mini-player:set-autoplay", {
      detail: { enabled: this.enabledValue }
    }))
  }
}
