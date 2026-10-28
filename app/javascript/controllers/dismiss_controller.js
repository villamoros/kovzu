import { Controller } from "@hotwired/stimulus"

// Cierra un aviso. Con data-dismiss-after-value="6000" se cierra solo a los 6 s.
export default class extends Controller {
  static values = { after: Number }

  connect() {
    if (this.afterValue > 0) this.timeout = setTimeout(() => this.close(), this.afterValue)
  }

  disconnect() {
    clearTimeout(this.timeout)
  }

  close() {
    this.element.remove()
  }
}
