import { Controller } from "@hotwired/stimulus"

// The restricted-content unlock token (feature 006). Module-scoped — NOT
// controller state — so it survives the controller reconnecting as Turbo swaps
// <body> during in-app navigation. It lives ONLY in JS memory: a hard refresh or
// new tab loads this module fresh (token = null), relocking the catalog
// (FR-010). Never written to storage or cookies.
let unlockToken = null

export default class extends Controller {
  connect() {
    this.addHeader = this.addHeader.bind(this)
    this.receive = this.receive.bind(this)
    document.addEventListener("turbo:before-fetch-request", this.addHeader)
    document.addEventListener("pin-lock:unlock", this.receive)
  }

  disconnect() {
    document.removeEventListener("turbo:before-fetch-request", this.addHeader)
    document.removeEventListener("pin-lock:unlock", this.receive)
  }

  // Attach the token to every Turbo fetch so the server can verify the session's
  // other half.
  addHeader(event) {
    if (unlockToken) event.detail.fetchOptions.headers["X-Pin-Unlock"] = unlockToken
  }

  // Fired by the unlock Turbo Stream handoff. Just remember the token — the next
  // in-app navigation renders unlocked. We deliberately do NOT reload the current
  // page: a same-URL visit is a Turbo page refresh (full reload), which would
  // wipe this in-memory token.
  receive(event) {
    unlockToken = event.detail.token
  }
}
