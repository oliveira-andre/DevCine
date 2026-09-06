import { Controller } from "@hotwired/stimulus"

// Page-level "offer thumbnail chooser after upload" toggle on the catalog item
// page. Remembered per browser so a bulk-upload session stays quiet across
// visits; the upload forms read the checkbox state at submit time.
const KEY = "catalogThumbnailChooser"

export default class extends Controller {
  static targets = ["box"]

  connect() {
    try {
      const stored = localStorage.getItem(KEY)
      if (stored !== null) this.boxTarget.checked = stored !== "0"
    } catch (_) { /* storage unavailable — default stays checked */ }
  }

  save() {
    try { localStorage.setItem(KEY, this.boxTarget.checked ? "1" : "0") } catch (_) {}
  }
}
