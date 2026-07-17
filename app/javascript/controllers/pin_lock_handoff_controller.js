import { Controller } from "@hotwired/stimulus"

// Appended by the unlock Turbo Stream (feature 006). On connect it hands the
// unlock token to the body-level pin-lock controller via a custom event, then
// removes itself so the token never lingers in the DOM.
export default class extends Controller {
  static values = { token: String }

  connect() {
    document.dispatchEvent(new CustomEvent("pin-lock:unlock", {
      detail: { token: this.tokenValue }
    }))
    this.element.remove()
  }
}
