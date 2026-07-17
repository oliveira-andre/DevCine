import { Controller } from "@hotwired/stimulus"

// Small dropdown menu (feature 005). Toggles a list open/closed and closes it on
// an outside click.
export default class extends Controller {
  static targets = ["list"]

  connect() {
    this.closeOnOutside = this.closeOnOutside.bind(this)
  }

  toggle(event) {
    event.stopPropagation()
    if (this.listTarget.hidden) {
      this.listTarget.hidden = false
      document.addEventListener("click", this.closeOnOutside)
    } else {
      this.close() // also removes the outside-click listener
    }
  }

  closeOnOutside(event) {
    if (!this.element.contains(event.target)) this.close()
  }

  close() {
    this.listTarget.hidden = true
    document.removeEventListener("click", this.closeOnOutside)
  }

  disconnect() {
    document.removeEventListener("click", this.closeOnOutside)
  }
}
