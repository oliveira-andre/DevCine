import TextareaAutogrow from "stimulus-textarea-autogrow"

// Description textareas grow with their content so nothing typed scrolls out of
// sight (admin catalog new/edit, video upload).
export default class extends TextareaAutogrow {
  connect() {
    super.connect()
    // The base component pins overflow:hidden. Keep it scrollable instead, so
    // text stays reachable once the CSS max-height caps the growth.
    this.element.style.overflow = "auto"
    // Inside a modal the dialog isn't laid out yet on connect and scrollHeight
    // reads 0 — measure again on the next frame.
    requestAnimationFrame(() => this.autogrow())
  }

  // scrollHeight covers content + padding but not borders, and the app's reset
  // is border-box, so add them back or the last line gets clipped.
  autogrow() {
    const el = this.element
    el.style.height = "auto"
    const styles = getComputedStyle(el)
    const borders = parseFloat(styles.borderTopWidth) + parseFloat(styles.borderBottomWidth)
    el.style.height = `${el.scrollHeight + borders}px`
  }
}
