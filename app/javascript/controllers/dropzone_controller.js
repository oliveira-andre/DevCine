import { Controller } from "@hotwired/stimulus"

// Drag-and-drop / click-to-browse upload zone (admin uploads). Single file only.
// Two modes:
//   autoSubmit (default) — picking/dropping a file submits the enclosing form
//     immediately with an "uploading" state (video slots).
//   autoSubmit: false — the zone just holds the pick: it shows the filename and
//     a clear (trash) button; the surrounding form is submitted normally
//     (subtitle SRT picker, which also needs language/default inputs).
export default class extends Controller {
  static targets = ["input", "label", "clear"]
  static values = { autoSubmit: { type: Boolean, default: true } }

  connect() {
    this.defaultLabel = this.hasLabelTarget ? this.labelTarget.textContent : ""
  }

  browse(event) {
    if (event.target === this.inputTarget) return // native input click — don't loop
    if (event.target.closest("[data-dropzone-target='clear']")) return
    this.inputTarget.click()
  }

  over(event) {
    event.preventDefault()
    this.element.classList.add("is-over")
  }

  leave() {
    this.element.classList.remove("is-over")
  }

  drop(event) {
    event.preventDefault()
    this.element.classList.remove("is-over")
    const file = event.dataTransfer?.files?.[0]
    if (!file) return

    // Single-file contract: keep only the first dropped file.
    const transfer = new DataTransfer()
    transfer.items.add(file)
    this.inputTarget.files = transfer.files
    this.picked(file)
  }

  changed() {
    const file = this.inputTarget.files && this.inputTarget.files[0]
    if (file) this.picked(file)
  }

  // Clear the held pick (autoSubmit: false mode).
  clear(event) {
    event.stopPropagation()
    this.inputTarget.value = ""
    this.element.classList.remove("is-filled")
    if (this.hasLabelTarget) this.labelTarget.textContent = this.defaultLabel
    if (this.hasClearTarget) this.clearTarget.hidden = true
  }

  picked(file) {
    if (this.autoSubmitValue) {
      this.element.classList.add("is-uploading")
      if (this.hasLabelTarget) this.labelTarget.textContent = `Uploading ${file.name}…`
      this.element.closest("form")?.requestSubmit()
    } else {
      this.element.classList.add("is-filled")
      if (this.hasLabelTarget) this.labelTarget.textContent = file.name
      if (this.hasClearTarget) this.clearTarget.hidden = false
    }
  }
}
