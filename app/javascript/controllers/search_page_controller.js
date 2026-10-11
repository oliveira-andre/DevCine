import { Controller } from "@hotwired/stimulus"

// On the /search page, hides the header's search link: the page has its own
// input, so the header one would be a second search box.
// The header lives outside #page-content and stream navigation never
// re-renders it, so the link is hidden rather than removed, and shown again on
// disconnect — when navigation swaps the search page out.
export default class extends Controller {
  connect() {
    this.headerLink = document.querySelector(".site-header .search-box")
    if (this.headerLink) this.headerLink.hidden = true
  }

  disconnect() {
    if (this.headerLink) this.headerLink.hidden = false
  }
}
