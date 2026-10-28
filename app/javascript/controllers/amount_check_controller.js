import { Controller } from "@hotwired/stimulus"

// HU-19: si el valor del pago no coincide con lo pactado, avisa y exige confirmarlo antes de enviar.
export default class extends Controller {
  static targets = ["input", "warning", "confirm"]
  static values = { expected: Number }

  connect() {
    this.check()
  }

  check() {
    const amount = Number(this.inputTarget.value.replace(/\D/g, ""))
    const differs = amount > 0 && this.expectedValue > 0 && amount !== this.expectedValue
    this.warningTarget.hidden = !differs
    this.confirmTarget.required = differs
    if (!differs) this.confirmTarget.checked = false
  }
}
