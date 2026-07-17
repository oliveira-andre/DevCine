import { Controller } from "@hotwired/stimulus"

// Copy a URL to the clipboard (the "Share" action). Falls back to the Web Share
// sheet where available; flashes a short confirmation in the label.
export default class extends Controller {
  static values = { text: String }
  static targets = ["label"]

  async copy() {
    try {
      await navigator.clipboard.writeText(this.textValue)
      this.flash("Copied!")
    } catch (_) {
      if (navigator.share) {
        try { await navigator.share({ url: this.textValue }) } catch (_) {}
      } else {
        this.flash("Copy failed")
      }
    }
  }

  flash(message) {
    if (!this.hasLabelTarget) return
    const original = this.labelTarget.textContent
    this.labelTarget.textContent = message
    setTimeout(() => { this.labelTarget.textContent = original }, 1500)
  }
}
