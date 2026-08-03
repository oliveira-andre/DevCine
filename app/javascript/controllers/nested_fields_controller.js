import { Controller } from "@hotwired/stimulus"

// Repeatable form rows — the subtitle tracks on the video upload form.
// The <template> holds one blank row whose name/id/for attributes carry a
// NEW_RECORD placeholder; each add clones it and stamps a fresh index so Rails
// reads the row as its own nested record. Removing a row just drops it from the
// DOM: nothing is persisted yet, so there is no destroy flag to set.
//
// Cloning the template's DocumentFragment and rewriting attributes — rather
// than string-replacing innerHTML — keeps this off insertAdjacentHTML and
// avoids re-parsing markup on every add.
export default class extends Controller {
  static targets = ["list", "template", "add"]
  static values = { max: { type: Number, default: 5 } }

  static PLACEHOLDER = "NEW_RECORD"
  static INDEXED_ATTRIBUTES = ["name", "id", "for"]

  connect() {
    // Indexes only ever climb. Reusing one after a removal would collide with a
    // row still in the form and silently merge the two into one record.
    this.nextIndex = this.rows().length
    this.syncAddButton()
  }

  add() {
    if (this.rows().length >= this.maxValue) return

    const { PLACEHOLDER, INDEXED_ATTRIBUTES } = this.constructor
    const fragment = this.templateTarget.content.cloneNode(true)
    const index = this.nextIndex++

    fragment.querySelectorAll(`[${INDEXED_ATTRIBUTES.join("], [")}]`).forEach((el) => {
      INDEXED_ATTRIBUTES.forEach((attribute) => {
        const value = el.getAttribute(attribute)
        if (value?.includes(PLACEHOLDER)) {
          el.setAttribute(attribute, value.replaceAll(PLACEHOLDER, index))
        }
      })
    })

    this.listTarget.appendChild(fragment)
    this.syncAddButton()
  }

  remove(event) {
    event.target.closest("[data-nested-fields-row]")?.remove()
    // Never leave the uploader with no row and no way back.
    if (this.rows().length === 0) this.add()
    this.syncAddButton()
  }

  rows() {
    return this.listTarget.querySelectorAll("[data-nested-fields-row]")
  }

  syncAddButton() {
    if (this.hasAddTarget) this.addTarget.hidden = this.rows().length >= this.maxValue
  }
}
