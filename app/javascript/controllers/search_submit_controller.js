import { Controller } from "@hotwired/stimulus"

// Debounced live-search: submits the enclosing form (into its Turbo Frame) a
// short moment after the admin stops typing (feature 009, US4).
export default class extends Controller {
  static values = { delay: { type: Number, default: 250 } }

  submit() {
    clearTimeout(this.timer)
    this.timer = setTimeout(() => this.element.requestSubmit(), this.delayValue)
  }

  disconnect() {
    clearTimeout(this.timer)
  }
}
