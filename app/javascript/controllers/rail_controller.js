import { Controller } from "@hotwired/stimulus"

// Scrolls a rail's track horizontally by ~one page (DESIGN §5.4).
export default class extends Controller {
  static targets = ["viewport"]

  prev() {
    this.scrollByPage(-1)
  }

  next() {
    this.scrollByPage(1)
  }

  scrollByPage(direction) {
    const track = this.viewportTarget
    track.scrollBy({ left: direction * track.clientWidth * 0.8, behavior: "smooth" })
  }
}
