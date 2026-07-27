import { Controller } from "@hotwired/stimulus"

// Marks the clicked season chip active immediately (feature 007, US3). It does
// NOT fetch — Turbo performs the episodes-frame swap via the chip's
// data-turbo-frame="episodes". Optimistic so "mark active" feels instant while
// the frame shows its loading state.
export default class extends Controller {
  select(event) {
    this.element.querySelectorAll(".season-chip.is-active").forEach((chip) => {
      chip.classList.remove("is-active")
      chip.removeAttribute("aria-current")
    })
    const chip = event.currentTarget
    chip.classList.add("is-active")
    chip.setAttribute("aria-current", "true")
  }
}
