import { Controller } from "@hotwired/stimulus"

// Subtitle icon + settings popup on the player page (feature 012). Talks to the
// persistent player (which owns the <video> + caption overlay) via document
// events, and persists the viewer's preferences (debounced).
export default class extends Controller {
  static targets = [
    "toggle", "popup", "textColor", "bgColor", "transparent",
    "fontSize", "fontWeight", "language", "languageRow"
  ]
  static values = {
    enabled: Boolean, textColor: String, bgColor: String,
    fontSize: Number, fontWeight: Number, updateUrl: String, tracks: Array
  }

  connect() {
    // Text/background color inputs are hidden inputs owned by their color-picker
    // controllers, seeded from their rendered `value`; don't reseed them here.
    if (this.hasTransparentTarget) this.transparentTarget.checked = !this.bgColorValue
    if (this.hasFontSizeTarget) this.fontSizeTarget.value = this.fontSizeValue || 100
    if (this.hasFontWeightTarget) this.fontWeightTarget.value = this.fontWeightValue || 400
    this.populateLanguages()
    this.closeOnOutside = this.closeOnOutside.bind(this)
  }

  disconnect() { document.removeEventListener("click", this.closeOnOutside) }

  // Off → enable; On → open the settings popup (FR-002/FR-005).
  iconClick() {
    if (this.enabledValue) this.togglePopup()
    else this.setEnabled(true)
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

  setEnabled(on) {
    this.enabledValue = on
    if (this.hasToggleTarget) {
      this.toggleTarget.classList.toggle("is-on", on)
      this.toggleTarget.title = on ? "Subtitles on" : "Subtitles off"
    }
    this.toPlayer("subtitles-toggle", { enabled: on })
    this.persist({ subtitles_enabled: on })
  }

  turnOff() {
    this.setEnabled(false)
    this.popupTarget.hidden = true
  }

  changeText() {
    const v = this.textColorTarget.value
    this.style({ textColor: v }); this.persist({ subtitle_text_color: v })
  }

  changeBg() {
    if (this.hasTransparentTarget) this.transparentTarget.checked = false
    const v = this.bgColorTarget.value
    this.style({ background: v }); this.persist({ subtitle_background_color: v })
  }

  toggleTransparent() {
    const v = this.transparentTarget.checked ? "" : this.bgColorTarget.value
    this.style({ background: v }); this.persist({ subtitle_background_color: v })
  }

  changeSize() {
    const v = Number(this.fontSizeTarget.value)
    this.style({ fontSize: v }); this.persist({ subtitle_font_size: v })
  }

  changeWeight() {
    const v = Number(this.fontWeightTarget.value)
    this.style({ fontWeight: v }); this.persist({ subtitle_font_weight: v })
  }

  changeLanguage() {
    this.toPlayer("subtitles-language", { trackId: this.languageTarget.value })
  }

  // --- helpers ---------------------------------------------------------------

  style(payload) { this.toPlayer("subtitles-style", payload) }

  toPlayer(name, detail) {
    document.dispatchEvent(new CustomEvent(`mini-player:${name}`, { detail }))
  }

  populateLanguages() {
    if (!this.hasLanguageTarget) return
    const tracks = this.tracksValue || []
    // Show the row for a single track too: the player auto-selects it, but an
    // empty popup reads as "no subtitles" to the viewer. Hide only when the
    // video truly has no tracks.
    if (!tracks.length) return
    this.languageTarget.replaceChildren()
    tracks.forEach((t) => {
      const o = document.createElement("option")
      o.value = t.id; o.textContent = t.label
      if (t.default) o.selected = true
      this.languageTarget.appendChild(o)
    })
    if (this.hasLanguageRowTarget) this.languageRowTarget.hidden = false
  }

  persist(data) {
    this.pending = { ...(this.pending || {}), ...data }
    clearTimeout(this.persistTimer)
    this.persistTimer = setTimeout(() => {
      const body = new URLSearchParams(this.pending)
      this.pending = null
      const token = document.querySelector('meta[name="csrf-token"]')?.content
      fetch(this.updateUrlValue, {
        method: "PATCH",
        headers: { "X-CSRF-Token": token, "Content-Type": "application/x-www-form-urlencoded", Accept: "application/json" },
        credentials: "same-origin",
        body
      }).catch(() => {})
    }, 300)
  }
}
