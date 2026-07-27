import { Controller } from "@hotwired/stimulus"

// Inline "Add a playlist" control in the add-to-playlist popover (feature 008,
// US1). Toggles a button ↔ an inline name input, blocks blank submits, and
// guards against a double create. The server's Turbo Stream replaces this whole
// element on success (reset) or re-renders it open with an error on failure.
export default class extends Controller {
  static targets = ["button", "form", "input"]
  static values = { open: Boolean }

  connect() {
    this.openValue ? this.showForm() : this.showButton()
  }

  open() {
    this.showForm()
    this.inputTarget.focus()
  }

  cancel() {
    this.inputTarget.value = ""
    this.showButton()
  }

  submit(event) {
    if (this.inputTarget.value.trim() === "") {
      event.preventDefault()
      this.inputTarget.focus()
      return
    }
    if (this.submitting) {
      event.preventDefault() // guard against a double create
      return
    }
    this.submitting = true
  }

  showForm() {
    this.buttonTarget.hidden = true
    this.formTarget.hidden = false
  }

  showButton() {
    this.formTarget.hidden = true
    this.buttonTarget.hidden = false
  }
}
