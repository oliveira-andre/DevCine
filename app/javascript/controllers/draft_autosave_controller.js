import { Controller } from "@hotwired/stimulus"
import { uploadInChunks } from "lib/chunk_uploader"

// Saves the upload form as a draft the moment it has both a title and a video
// file, so the file is on the server and ffmpeg can suggest thumbnails before
// the uploader commits.
//
// The file itself is streamed FIRST, in small chunks (lib/chunk_uploader), so
// a multi-GB upload never rides a single long request into the proxy timeout.
// The draft submit then carries only the chunk id + metadata; videos#create
// assembles the scratch file into Active Storage. Without JavaScript the form
// stays a plain one-shot multipart upload.
export default class extends Controller {
  static targets = ["title", "file", "status", "draft", "chunkId", "chunkName", "chunkType"]
  static values = { chunkUrl: String }

  maybeSave() {
    // The submit replaces this form, but a second `change` can still land first
    // (picking a file blurs the title). Guard so the draft is created once.
    if (this.saving) return
    if (!this.ready) return

    this.saving = true
    if (this.hasStatusTarget) this.statusTarget.hidden = false
    this.save()
  }

  async save() {
    const file = this.fileTarget.files[0]
    try {
      const done = await uploadInChunks(file, this.chunkUrlValue, {
        onProgress: (pct) => this.progress(`Uploading… ${pct}%`)
      })
      this.chunkIdTarget.value = done.id
      this.chunkNameTarget.value = done.filename
      this.chunkTypeTarget.value = done.contentType
      // The bytes are on the server — submit only the id. The input is
      // `required`, so lift that before clearing it or requestSubmit's HTML
      // validation would silently block the draft.
      this.fileTarget.required = false
      this.fileTarget.value = ""
    } catch (_) {
      this.saving = false
      this.progress("Upload failed — pick the file to try again.")
      return
    }

    this.progress("Saving…")
    // Tells the server this is the autosave, not someone pressing Upload — the
    // flag is what separates "save a draft" from "finish the upload".
    if (this.hasDraftTarget) this.draftTarget.value = "1"
    // requestSubmit (not submit) so Turbo handles it and HTML validation runs.
    this.element.requestSubmit()
  }

  progress(text) {
    if (!this.hasStatusTarget) return
    const label = this.statusTarget.querySelector("span")
    if (label) label.textContent = text
  }

  get ready() {
    const titled = this.hasTitleTarget && this.titleTarget.value.trim() !== ""
    const filed = this.hasFileTarget && this.fileTarget.files.length > 0
    return titled && filed
  }
}
