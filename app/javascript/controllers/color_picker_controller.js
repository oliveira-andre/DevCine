import ColorPicker from "stimulus-color-picker"

// Wraps stimulus-color-picker (feature 012). The base component sets the hidden
// input on save but dispatches no event and emits 8-digit HEXA; normalize to
// #RRGGBB (or "" when cleared → transparent) and fire a bubbling change so the
// subtitle-settings controller reacts.
export default class extends ColorPicker {
  onSave(color) {
    super.onSave(color)
    const v = this.inputTarget.value
    if (v && v.length > 7) this.inputTarget.value = v.slice(0, 7)
    this.inputTarget.dispatchEvent(new Event("change", { bubbles: true }))
  }
}
