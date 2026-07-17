import { Controller } from "@hotwired/stimulus"

// Full-page navigation from inside a Turbo Frame / Stream (feature 006): a
// frame-scoped redirect would only swap the frame, so we break out to _top.
export default class extends Controller {
  static values = { url: String }

  connect() {
    if (window.Turbo) window.Turbo.visit(this.urlValue, { action: "replace" })
    else window.location.assign(this.urlValue)
  }
}
