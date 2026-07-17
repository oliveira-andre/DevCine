import { Controller } from "@hotwired/stimulus"

// "Read more" toggle (feature 005). Collapses long content (video description,
// long comments) behind a trigger; clicking expands/collapses. Pure Stimulus —
// Hotwire-native (Constitution I).
export default class extends Controller {
  static targets = ["trigger"]
  static values = { expanded: Boolean }

  toggle() {
    this.expandedValue = !this.expandedValue
  }

  expandedValueChanged() {
    this.element.classList.toggle("is-expanded", this.expandedValue)
    if (this.hasTriggerTarget) {
      this.triggerTarget.textContent = this.expandedValue ? "Read less" : "Read more"
    }
  }
}
