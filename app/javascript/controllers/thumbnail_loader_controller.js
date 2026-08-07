import { Controller } from "@hotwired/stimulus"

// Fetches the ffmpeg thumbnail suggestions for the catalog edit modal in its
// own request: the modal opens instantly with a "Fetching thumbnails…" note,
// and the pickable frames are appended in place (just above the Save button)
// when ffmpeg answers. The picked radio rides along with the enclosing form as
// video[thumbnail_signed_id], which the update action promotes on save.
export default class extends Controller {
  static targets = ["status", "frames"]
  static values = { url: String }

  connect() {
    this.load()
  }

  async load() {
    try {
      const response = await fetch(this.urlValue, {
        // The endpoint renders the bare frame variant for frame requests.
        headers: { "Turbo-Frame": "thumbnail_suggestions", Accept: "text/html" },
        credentials: "same-origin"
      })
      if (!response.ok) throw new Error(`suggestions failed: ${response.status}`)

      const doc = new DOMParser().parseFromString(await response.text(), "text/html")
      const frame = doc.querySelector("turbo-frame#thumbnail_suggestions")
      if (!frame) throw new Error("no suggestions frame in response")

      this.statusTarget.hidden = true
      this.framesTarget.innerHTML = frame.innerHTML
    } catch {
      // Best-effort, like everywhere else in the thumbnail pipeline: the edit
      // form must stay fully usable without suggestions.
      this.statusTarget.textContent = "Couldn’t fetch thumbnails — you can save without one."
    }
  }
}
