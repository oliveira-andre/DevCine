import { Controller } from "@hotwired/stimulus"

// Saves the upload form as a draft the moment it has both a title and a video
// file, so the file is on the server and ffmpeg can suggest thumbnails before
// the uploader commits. The response swaps this form for its update-mode
// counterpart, which is where the suggestions appear.
//
// This is the only JavaScript in the flow — the frames themselves are fetched
// by a lazy Turbo Frame, not from here.
export default class extends Controller {
  static targets = ["title", "file", "status", "draft"]

  maybeSave() {
    // The submit replaces this form, but a second `change` can still land first
    // (picking a file blurs the title). Guard so the draft is created once.
    if (this.saving) return
    if (!this.ready) return

    this.saving = true
    if (this.hasStatusTarget) this.statusTarget.hidden = false
    // Tells the server this is the autosave, not someone pressing Upload — the
    // flag is what separates "save a draft" from "finish the upload".
    if (this.hasDraftTarget) this.draftTarget.value = "1"
    // requestSubmit (not submit) so Turbo handles it and HTML validation runs.
    this.element.requestSubmit()
  }

  get ready() {
    const titled = this.hasTitleTarget && this.titleTarget.value.trim() !== ""
    const filed = this.hasFileTarget && this.fileTarget.files.length > 0
    return titled && filed
  }
}
