import { Controller } from "@hotwired/stimulus"

// Alterna modo claro y oscuro en <html data-theme>.
// Si la persona no ha elegido, sigue la preferencia del sistema.
// <button data-controller="theme" data-action="theme#toggle">
export default class extends Controller {
  static values = { storageKey: { type: String, default: "kz-theme" } }

  connect() {
    this.media = window.matchMedia("(prefers-color-scheme: dark)")
    this.followSystem = () => {
      if (!this.stored) this.apply(this.media.matches ? "dark" : "light")
    }
    this.media.addEventListener("change", this.followSystem)
    this.sync()
  }

  disconnect() {
    this.media.removeEventListener("change", this.followSystem)
  }

  toggle() {
    const next = this.current === "dark" ? "light" : "dark"
    try { localStorage.setItem(this.storageKeyValue, next) } catch {}
    this.apply(next)
  }

  apply(theme) {
    document.documentElement.dataset.theme = theme
    this.sync()
  }

  sync() {
    const dark = this.current === "dark"
    this.element.setAttribute("aria-pressed", String(dark))
    this.element.setAttribute("aria-label", dark ? "Usar modo claro" : "Usar modo oscuro")
  }

  get current() {
    return document.documentElement.dataset.theme
  }

  get stored() {
    try { return localStorage.getItem(this.storageKeyValue) } catch { return null }
  }
}
