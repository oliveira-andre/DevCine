import { Controller } from "@hotwired/stimulus"

// "Video file" vs "Live (embed URL)" switch on the member upload form. The
// inactive side is hidden AND its inputs disabled — disabled controls neither
// submit nor run HTML validation, so each mode only requires its own fields
// (and draft-autosave stays dormant in live mode: a disabled file input never
// has a pick).
export default class extends Controller {
  static targets = ["fileSection", "liveSection"]

  connect() {
    // Sync with the checked radio (a validation re-render keeps live mode).
    const live = this.element.querySelector("input[name='upload_mode'][value='live']")
    this.apply(!!live?.checked)
  }

  switch(event) {
    this.apply(event.target.value === "live")
  }

  apply(live) {
    this.liveSectionTargets.forEach((el) => this.toggle(el, live))
    this.fileSectionTargets.forEach((el) => this.toggle(el, !live))
  }

  toggle(section, on) {
    section.hidden = !on
    section.querySelectorAll("input, select, textarea").forEach((input) => {
      input.disabled = !on
    })
  }
}
