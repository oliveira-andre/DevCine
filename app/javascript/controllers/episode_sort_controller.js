import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"

// Drag-to-reorder a season's episodes (admin catalog serie page). Rows are
// dragged by their grip handle; the drop PATCHes update_position with the new
// 1-based position, the server insert_at-shifts the neighbors, and the
// renumbered season block streams back to replace the optimistic DOM order.
export default class extends Controller {
  connect() {
    this.sortable = Sortable.create(this.element, {
      animation: 150,
      handle: "[data-sort-handle]",
      draggable: "[data-position-url]",
      onEnd: (event) => this.reorder(event)
    })
  }

  disconnect() {
    this.sortable?.destroy()
    this.sortable = null
  }

  async reorder(event) {
    const rows = [...this.element.querySelectorAll("[data-position-url]")]
    const position = rows.indexOf(event.item) + 1
    if (position < 1) return

    const token = document.querySelector('meta[name="csrf-token"]')?.content
    try {
      const response = await fetch(event.item.dataset.positionUrl, {
        method: "PATCH",
        headers: {
          "X-CSRF-Token": token,
          "Content-Type": "application/x-www-form-urlencoded",
          Accept: "text/vnd.turbo-stream.html"
        },
        credentials: "same-origin",
        body: new URLSearchParams({ position })
      })
      if (response.ok) window.Turbo.renderStreamMessage(await response.text())
    } catch (_) {
      // Leave the optimistic order on a network blip — the next reload shows
      // the server's truth.
    }
  }
}
