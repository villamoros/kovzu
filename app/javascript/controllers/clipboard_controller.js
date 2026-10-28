import { Controller } from "@hotwired/stimulus"

// Copia un texto (el enlace de cotización) y confirma en el mismo botón.
export default class extends Controller {
  static values = { text: String }

  async copy(event) {
    event.preventDefault()
    const button = event.currentTarget
    const label = button.textContent
    try {
      await navigator.clipboard.writeText(this.textValue)
      button.textContent = "Copiado"
    } catch {
      window.prompt("Copia el enlace:", this.textValue)
    }
    setTimeout(() => { button.textContent = label }, 1600)
  }
}
