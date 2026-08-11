import { Controller } from "@hotwired/stimulus"
import { uploadInChunks } from "lib/chunk_uploader"

// Resumable upload zone for large catalog video files. Instead of POSTing the
// whole file in one multipart request (which trips the reverse-proxy's response
// timeout at ~30s and 502s on multi-GB videos), it slices the file in the
// browser and streams the chunks one small request at a time to
// /admin/chunked_uploads. When every chunk has landed it submits the enclosing
// form carrying only the tiny upload id — the server reassembles + attaches.
//
// Drag-and-drop / click-to-browse behaviour mirrors dropzone_controller (which
// still handles small, single-shot pickers like the subtitle SRT field).
export default class extends Controller {
  static targets = ["input", "label", "id", "filename", "contentType"]
  static values = {
    url: String,
    chunkSize: { type: Number, default: 8 * 1024 * 1024 }, // 8 MB
    retries: { type: Number, default: 3 }
  }

  connect() {
    this.defaultLabel = this.hasLabelTarget ? this.labelTarget.textContent : ""
    this.uploading = false
  }

  browse(event) {
    if (event.target === this.inputTarget) return // native input click — don't loop
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
    if (file) this.start(file)
  }

  changed() {
    const file = this.inputTarget.files && this.inputTarget.files[0]
    if (file) this.start(file)
  }

  async start(file) {
    if (this.uploading) return
    this.uploading = true
    this.element.classList.add("is-uploading")

    let done
    try {
      done = await uploadInChunks(file, this.urlValue, {
        chunkSize: this.chunkSizeValue,
        retries: this.retriesValue,
        onProgress: (pct) => this.setLabel(`Uploading ${file.name}… ${pct}%`)
      })
    } catch (error) {
      this.uploading = false
      this.element.classList.remove("is-uploading")
      this.element.classList.add("is-error")
      this.setLabel("Upload failed — click to try again")
      return
    }

    // Hand the reassembled file to the form: the big bytes are already on the
    // server, so clear the file input and submit only the id + metadata.
    this.idTarget.value = done.id
    this.filenameTarget.value = done.filename
    this.contentTypeTarget.value = done.contentType
    this.inputTarget.value = ""
    this.setLabel(`Finishing ${file.name}…`)
    this.element.requestSubmit ? this.element.requestSubmit() : this.element.submit()
  }

  setLabel(text) {
    if (this.hasLabelTarget) this.labelTarget.textContent = text
  }
}
