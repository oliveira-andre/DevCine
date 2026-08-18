import { Controller } from "@hotwired/stimulus"

// HH:MM:SS duration mask (skip markers). The visible input only ever shows
// the 00:00:00 shape — digits fill from the right like a timer (typing "130"
// reads as 1 minute 30) — and the hidden integer field, which is what actually
// submits, always carries the parsed total seconds. Blur normalizes overflowed
// groups (00:00:90 → 00:01:30). Clearing the input clears the marker.
export default class extends Controller {
  static targets = ["display", "seconds"]

  connect() {
    // Seed the display from the stored seconds when the field renders empty.
    if (this.displayTarget.value === "" && this.secondsTarget.value !== "") {
      this.displayTarget.value = this.format(parseInt(this.secondsTarget.value, 10))
    }
  }

  input() {
    const digits = this.displayTarget.value.replace(/\D/g, "").slice(-6)
    this.displayTarget.value = digits === "" ? "" : this.mask(digits)
    this.syncSeconds()
  }

  // 00:00:90 → 00:01:30 once the field settles.
  normalize() {
    this.syncSeconds()
    const value = this.secondsTarget.value
    this.displayTarget.value = value === "" ? "" : this.format(parseInt(value, 10))
  }

  syncSeconds() {
    const digits = this.displayTarget.value.replace(/\D/g, "")
    if (digits === "") { this.secondsTarget.value = "" ; return }
    const padded = digits.padStart(6, "0")
    const h = parseInt(padded.slice(0, 2), 10)
    const m = parseInt(padded.slice(2, 4), 10)
    const s = parseInt(padded.slice(4, 6), 10)
    this.secondsTarget.value = h * 3600 + m * 60 + s
  }

  mask(digits) {
    const padded = digits.padStart(6, "0")
    return `${padded.slice(0, 2)}:${padded.slice(2, 4)}:${padded.slice(4, 6)}`
  }

  format(total) {
    if (!Number.isFinite(total)) return ""
    const h = Math.floor(total / 3600)
    const m = Math.floor((total % 3600) / 60)
    const s = total % 60
    const pad = (n) => String(n).padStart(2, "0")
    return `${pad(h)}:${pad(m)}:${pad(s)}`
  }
}
