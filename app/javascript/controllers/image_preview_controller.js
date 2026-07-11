import { Controller } from "@hotwired/stimulus"

// Live client-side preview for an image file input (avatar, cover, thumbnail).
// On selecting an image, shows it in the preview <img> before submitting.
export default class extends Controller {
  static targets = ["input", "preview"]

  show() {
    const file = this.inputTarget.files && this.inputTarget.files[0]
    if (!file || !file.type.startsWith("image/")) return // ignore non-images

    if (this.url) URL.revokeObjectURL(this.url)
    this.url = URL.createObjectURL(file)
    this.previewTarget.src = this.url
    this.previewTarget.classList.add("is-visible")
  }

  disconnect() {
    if (this.url) URL.revokeObjectURL(this.url)
  }
}
