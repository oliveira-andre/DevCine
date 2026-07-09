import { Controller } from "@hotwired/stimulus"

// The header search control navigates to the dedicated /search page (it never
// searches inline). It's a link, so clicks already navigate; this also routes
// on focus (keyboard tab). FR-009.
export default class extends Controller {
  go(event) {
    event.preventDefault()
    const url = this.element.getAttribute("href") || "/search"
    window.Turbo ? window.Turbo.visit(url) : (window.location = url)
  }
}
