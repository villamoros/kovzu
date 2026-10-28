# Catálogo vivo del sistema de diseño. Ruta sugerida (solo desarrollo):
#   get "/design", to: "design_system#show" if Rails.env.development?
class DesignSystemController < ApplicationController
  def show
    @milestones = [
      { title: "Requerimiento recibido", state: :done, committed: Date.new(2026, 10, 20), actual: Date.new(2026, 10, 20), by: "Cliente" },
      { title: "Propuesta aprobada", state: :done, committed: Date.new(2026, 10, 23), actual: Date.new(2026, 10, 22), by: "Laura Gómez" },
      { title: "Muestra patrón", state: :late, committed: Date.new(2026, 10, 27), by: "Taller Cartón Valle" },
      { title: "Producción", state: :pending, committed: Date.new(2026, 11, 3) },
      { title: "Inspección y despacho", state: :pending, committed: Date.new(2026, 11, 5) }
    ]
  end
end
