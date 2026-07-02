import { Controller } from "@hotwired/stimulus"

// Disables the submit button and shows an inline message while the password
// and its confirmation don't match (FR-024). The server still validates the
// confirmation regardless of client state (FR-025).
export default class extends Controller {
  static targets = ["password", "confirmation", "submit", "message"]

  connect() {
    this.check()
  }

  check() {
    const password = this.passwordTarget.value
    const confirmation = this.confirmationTarget.value

    // Only complain once the user has started typing a confirmation.
    if (confirmation.length > 0 && password !== confirmation) {
      this.setMismatch(true)
    } else {
      this.setMismatch(false)
    }
  }

  setMismatch(mismatched) {
    this.submitTarget.disabled = mismatched
    this.confirmationTarget.setAttribute("aria-invalid", mismatched ? "true" : "false")
    this.messageTarget.textContent = mismatched ? "passwords do not match" : ""
  }
}
