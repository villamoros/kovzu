import { Controller } from "@hotwired/stimulus"

// HU-01: revisa los archivos antes de subirlos. Quita los que pesan más de lo permitido
// o tienen un formato no admitido, explica por qué y ofrece pegar un enlace.
export default class extends Controller {
  static targets = ["input", "list", "links"]

  check() {
    const input = this.inputTarget
    const maxBytes = Number(input.dataset.maxBytes)
    const extensions = input.dataset.extensions.split(",")
    const kept = new DataTransfer()
    const rows = []
    let rejected = false

    for (const file of input.files) {
      const extension = file.name.split(".").pop().toLowerCase()
      let problem = null
      if (file.size > maxBytes) problem = `pesa ${this.megabytes(file.size)}, más de ${this.megabytes(maxBytes)}. Pega un enlace de descarga abajo.`
      else if (!extensions.includes(extension)) problem = "no es un formato admitido."

      if (problem) rejected = true
      else kept.items.add(file)
      rows.push(this.row(file, problem))
    }

    input.files = kept.files
    this.listTarget.replaceChildren(...rows)
    if (rejected && this.hasLinksTarget) this.linksTarget.focus()
  }

  row(file, problem) {
    const item = document.createElement("li")
    item.className = problem ? "kz-error" : "text-ink-muted"
    item.textContent = problem ? `${file.name} no se adjuntó: ${problem}` : `${file.name} · ${this.megabytes(file.size)}`
    return item
  }

  megabytes(bytes) {
    return `${(bytes / 1024 / 1024).toLocaleString("es-CO", { maximumFractionDigits: 1 })} MB`
  }
}
