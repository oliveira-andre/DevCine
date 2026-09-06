import { Controller } from "@hotwired/stimulus"

// Audio-track menu on the player page (beside the captions popup, same
// chrome). Talks to the persistent player via a document event — the player
// owns the <video> and the synced alternate-audio element.
export default class extends Controller {
  static targets = ["toggle", "popup", "select"]

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
  }
}
