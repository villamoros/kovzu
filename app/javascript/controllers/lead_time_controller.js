import { Controller } from "@hotwired/stimulus"

// CU-01 4a: avisa si la fecha pedida es menor que el plazo mínimo de la categoría. No bloquea el envío.
export default class extends Controller {
  static targets = ["input", "warning"]
  static values = { earliest: String }

  connect() {
    this.check()
  }

  check() {
    if (!this.hasWarningTarget || !this.earliestValue) return

    const value = this.inputTarget.value
    this.warningTarget.hidden = !value || value >= this.earliestValue
  }
}
