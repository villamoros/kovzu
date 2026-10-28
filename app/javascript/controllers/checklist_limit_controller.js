import { Controller } from "@hotwired/stimulus"

// Limita cuántas casillas se pueden marcar y muestra el conteo.
// <form data-controller="checklist-limit" data-checklist-limit-max-value="3">
export default class extends Controller {
  static targets = ["option", "status"]
  static values = { max: Number }

  connect() {
    this.element.addEventListener("change", this.update)
    this.update()
  }

  disconnect() {
    this.element.removeEventListener("change", this.update)
  }

  update = () => {
    const free = this.optionTargets.filter((option) => !option.defaultDisabled)
    const checked = free.filter((option) => option.checked).length
    free.forEach((option) => { option.disabled = !option.checked && checked >= this.maxValue })
    if (this.hasStatusTarget) {
      this.statusTarget.textContent = checked === 0 ? "Ninguno elegido" : `${checked} de ${this.maxValue} elegidos`
    }
  }
}
