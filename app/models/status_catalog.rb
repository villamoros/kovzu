# Estados de cada entidad con su etiqueta y tono visual (ver kz_status).
# Tonos: neutral, info (avance), warning (requiere atención), success (cumplido), danger (excepción).
module StatusCatalog
  STATUSES = {
    requirement: {
      "en_revision"       => { label: "En revisión",       tone: :neutral },
      "esperando_cliente" => { label: "Esperando cliente", tone: :warning },
      "completo"          => { label: "Completo",          tone: :success },
      "no_viable"         => { label: "No viable",         tone: :neutral }
    },
    order: {
      "en_preparacion"    => { label: "En preparación",    tone: :neutral },
      "cotizando"         => { label: "Cotizando",         tone: :info },
      "propuesta_enviada" => { label: "Propuesta enviada", tone: :info },
      "confirmado"        => { label: "Confirmado",        tone: :info },
      "en_curso"          => { label: "En curso",          tone: :info },
      "escalado"          => { label: "Escalado",          tone: :danger },
      "entregado"         => { label: "Entregado",         tone: :success },
      "cancelado"         => { label: "Cancelado",         tone: :neutral }
    },
    sub_order: {
      "preparacion"             => { label: "En preparación",          tone: :neutral },
      "cotizando"               => { label: "Cotizando",               tone: :info },
      "asignado"                => { label: "Taller asignado",         tone: :info },
      "anticipo_pendiente"      => { label: "Anticipo pendiente",      tone: :warning },
      "muestra_pendiente"       => { label: "Muestra pendiente",       tone: :warning },
      "en_produccion"           => { label: "En producción",           tone: :info },
      "inspeccion"              => { label: "Inspección",              tone: :warning },
      "aprobado"                => { label: "Aprobado",                tone: :success },
      "aprobado_con_desviacion" => { label: "Aprobado con desviación", tone: :warning },
      "rechazado"               => { label: "Rechazado",               tone: :danger },
      "reproceso"               => { label: "Reproceso",               tone: :danger },
      "despachado"              => { label: "Despachado",              tone: :info },
      "entregado"               => { label: "Entregado",               tone: :success },
      "escalado"                => { label: "Escalado",                tone: :danger },
      "cancelado"               => { label: "Cancelado",               tone: :neutral }
    },
    tech_sheet: {
      "borrador"    => { label: "Borrador",    tone: :neutral },
      "lista"       => { label: "Lista",       tone: :info },
      "aceptada"    => { label: "Aceptada",    tone: :success },
      "reemplazada" => { label: "Reemplazada", tone: :neutral }
    },
    quote: {
      "solicitada" => { label: "Solicitada", tone: :neutral },
      "recibida"   => { label: "Recibida",   tone: :info },
      "rechazada"  => { label: "No cotiza",  tone: :neutral },
      "elegida"    => { label: "Elegida",    tone: :success },
      "no_elegida" => { label: "No elegida", tone: :neutral },
      "vencida"    => { label: "Vencida",    tone: :warning }
    },
    workshop: {
      "prospecto"       => { label: "Prospecto",       tone: :neutral },
      "en_verificacion" => { label: "En verificación", tone: :info },
      "verificado"      => { label: "Verificado",      tone: :success },
      "pausado"         => { label: "Pausado",         tone: :warning },
      "retirado"        => { label: "Retirado",        tone: :neutral }
    }
  }.freeze

  def self.keys(kind) = STATUSES.fetch(kind).keys

  # Para `enum :status, StatusCatalog.enum_for(:order)`: valores guardados como texto.
  def self.enum_for(kind) = keys(kind).index_with(&:itself)

  def self.fetch(kind, key)
    STATUSES.fetch(kind).fetch(key.to_s) { { label: key.to_s.humanize, tone: :neutral } }
  end

  def self.label(kind, key) = fetch(kind, key)[:label]
end
