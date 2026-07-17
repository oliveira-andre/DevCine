import { Controller } from "@hotwired/stimulus"

// Custom file uploader. The native <input type=file> is transparent and overlays
// the whole container, so the box is the click target (and stays interactable for
// tests). On selection we mark the container filled and reflect state:
//   - image mode: render a live preview that fills the box
//   - file mode (video): show the filename with a check, no preview
export default class extends Controller {
  static targets = ["input", "preview", "filename"]

  change() {
    const file = this.inputTarget.files && this.inputTarget.files[0]
    if (!file) return

    this.element.classList.add("is-filled")

    if (this.hasFilenameTarget) this.filenameTarget.textContent = file.name

    if (this.hasPreviewTarget && file.type.startsWith("image/")) {
      if (this.url) URL.revokeObjectURL(this.url)
      this.url = URL.createObjectURL(file)
      this.previewTarget.src = this.url
      this.previewTarget.classList.add("is-visible")
    }
  }

  disconnect() {
    if (this.url) URL.revokeObjectURL(this.url)
  }
}
