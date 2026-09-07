import { Controller } from "@hotwired/stimulus"

// Audio-track menu on the player page (beside the captions popup, same
// chrome). Talks to the persistent player via a document event — the player
// owns the <video> and the synced alternate-audio element.
export default class extends Controller {
  static targets = ["toggle", "popup", "select"]
  static values = { url: String }

  connect() {
    this.closeOnOutside = this.closeOnOutside.bind(this)
  }

  disconnect() {
    document.removeEventListener("click", this.closeOnOutside)
  }

  togglePopup() {
    this.popupTarget.hidden = !this.popupTarget.hidden
    if (!this.popupTarget.hidden) document.addEventListener("click", this.closeOnOutside)
    else document.removeEventListener("click", this.closeOnOutside)
  }

  closeOnOutside(event) {
    if (!this.element.contains(event.target)) {
      this.popupTarget.hidden = true
      document.removeEventListener("click", this.closeOnOutside)
    }
  }

  change() {
    document.dispatchEvent(new CustomEvent("mini-player:audio-track", {
      detail: { trackId: this.selectTarget.value }
    }))
    this.persist()
  }

  // Remember the choice for this TITLE (serie/movie) — the server updates the
  // single per-title row, so repeated changes never pile up.
  persist() {
    if (!this.hasUrlValue) return
    const name = this.selectTarget.selectedOptions[0]?.textContent.trim()
    const token = document.querySelector('meta[name="csrf-token"]')?.content
    fetch(this.urlValue, {
      method: "PATCH",
      headers: { "X-CSRF-Token": token, "Content-Type": "application/json" },
      credentials: "same-origin",
      body: JSON.stringify({ audio_track_name: name })
    }).catch(() => {})
  }
}
