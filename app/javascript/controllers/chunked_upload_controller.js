import { Controller } from "@hotwired/stimulus"

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

    const id = this.uuid()
    const total = Math.max(1, Math.ceil(file.size / this.chunkSizeValue))

    try {
      for (let index = 0; index < total; index++) {
        const start = index * this.chunkSizeValue
        const chunk = file.slice(start, start + this.chunkSizeValue)
        await this.sendChunk(id, index, chunk)
        this.setLabel(`Uploading ${file.name}… ${Math.round(((index + 1) / total) * 100)}%`)
      }
    } catch (error) {
      this.uploading = false
      this.element.classList.remove("is-uploading")
      this.element.classList.add("is-error")
      this.setLabel("Upload failed — click to try again")
      return
    }

    // Hand the reassembled file to the form: the big bytes are already on the
    // server, so clear the file input and submit only the id + metadata.
    this.idTarget.value = id
    this.filenameTarget.value = file.name
    this.contentTypeTarget.value = file.type || "application/octet-stream"
    this.inputTarget.value = ""
    this.setLabel(`Finishing ${file.name}…`)
    this.element.requestSubmit ? this.element.requestSubmit() : this.element.submit()
  }

  async sendChunk(id, index, chunk) {
    let lastError
    for (let attempt = 0; attempt <= this.retriesValue; attempt++) {
      try {
        const body = new FormData()
        body.append("upload_id", id)
        body.append("index", index)
        body.append("chunk", chunk)

        const response = await fetch(this.urlValue, {
          method: "POST",
          body,
          credentials: "same-origin",
          headers: { "X-CSRF-Token": this.csrfToken() }
        })
        if (!response.ok) throw new Error(`chunk ${index} failed: ${response.status}`)
        return
      } catch (error) {
        lastError = error
      }
    }
    throw lastError
  }

  setLabel(text) {
    if (this.hasLabelTarget) this.labelTarget.textContent = text
  }

  csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content || ""
  }

  // crypto.randomUUID is available in every browser `allow_browser :modern`
  // admits; the fallback keeps a hand-run dev browser from throwing.
  uuid() {
    if (window.crypto?.randomUUID) return window.crypto.randomUUID()
    return "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx".replace(/[xy]/g, (c) => {
      const r = (Math.random() * 16) | 0
      const v = c === "x" ? r : (r & 0x3) | 0x8
      return v.toString(16)
    })
  }
}
