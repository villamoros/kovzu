# Parte de un pedido que fabrica un solo taller.
class SubOrder < ApplicationRecord
  class TransitionError < ::TransitionError; end

  MAX_QUOTES = 3
  QUOTE_LINK_TTL = 5.days

  enum :status, StatusCatalog.enum_for(:sub_order), default: "preparacion", validate: true

  belongs_to :order, inverse_of: :sub_orders
  belongs_to :category
  belongs_to :workshop, optional: true
  has_many :tech_sheets, -> { order(version: :desc) }, dependent: :destroy, inverse_of: :sub_order
  has_many :quotes, -> { order(:created_at) }, dependent: :destroy
  has_many :milestones, -> { order(:position) }, dependent: :destroy
  has_many :samples, -> { order(:number) }, dependent: :destroy

  validates :title, presence: true
  validates :quantity, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true

  def current_tech_sheet = tech_sheets.first

  def open_quotes = quotes.where(status: %w[solicitada recibida])

  # Pide cotización a 1–3 talleres verificados con la ficha lista (HU-04).
  def request_quotes!(workshop_ids, by:)
    sheet = current_tech_sheet
    raise TransitionError, "La ficha técnica debe estar lista antes de pedir cotizaciones." unless sheet&.lista? || sheet&.aceptada?

    workshops = Workshop.where(id: Array(workshop_ids).compact_blank).to_a
    raise TransitionError, "Elige entre 1 y #{MAX_QUOTES} talleres." unless workshops.size.between?(1, MAX_QUOTES)
    raise TransitionError, "Ya hay #{open_quotes.count} cotizaciones abiertas; el máximo es #{MAX_QUOTES}." if open_quotes.count + workshops.size > MAX_QUOTES

    eligible = Workshop.candidates_for(self).where(id: workshops.map(&:id)).pluck(:id)
    rejected = workshops.reject { |workshop| eligible.include?(workshop.id) }
    raise TransitionError, "No cumplen las condiciones para cotizar: #{rejected.map(&:name).to_sentence}." if rejected.any?

    transaction do
      created = workshops.map do |workshop|
        quotes.create!(workshop:, tech_sheet: sheet, link_expires_at: QUOTE_LINK_TTL.from_now)
      end
      update!(status: "cotizando")
      order.update!(status: "cotizando") if order.en_preparacion?
      AuditEvent.record!(self, "cotizacion.solicitada", actor: by, data: { workshops: workshops.map(&:name) })
      created
    end
  end

  SAMPLE_STATUSES = %w[asignado anticipo_pendiente muestra_pendiente].freeze

  def current_sample = samples.last

  def can_register_sample? = status.in?(SAMPLE_STATUSES) && !current_sample&.por_revisar?

  # El operador registra la muestra con fotos y el cliente la revisa (HU-09).
  def register_sample!(kind:, notes:, photos:, by:)
    raise TransitionError, "Este subpedido no está esperando muestra." unless status.in?(SAMPLE_STATUSES)
    raise TransitionError, "La muestra anterior sigue esperando respuesta del cliente." if current_sample&.por_revisar?

    sample = transaction do
      created = samples.create!(number: samples.maximum(:number).to_i + 1, kind:, notes:, photos:, registered_by: by)
      update!(status: "muestra_pendiente")
      order.update!(status: "en_curso") if order.confirmado?
      AuditEvent.record!(self, "muestra.registrada", actor: by, data: { number: created.number })
      created
    end
    ClientMailer.with(order:, headline: "Tu muestra está lista para revisar",
                      body: "Registramos la muestra #{sample.number} de #{title}. Revísala y apruébala o pide ajustes.").order_update.deliver_later
    sample
  end

  # Hitos estándar desde una fecha de inicio, en días hábiles.
  def plan_milestones!(start_on:, sample_days: 3, production_days: 8)
    steps = [
      [ "anticipo", "Anticipo al taller", 1 ],
      [ "muestra", "Muestra patrón", sample_days ],
      [ "produccion", "Producción", production_days ],
      [ "inspeccion", "Inspección", 1 ],
      [ "despacho", "Despacho y entrega", 1 ]
    ]
    date = start_on.to_date
    steps.each_with_index.map do |(kind, title, days), index|
      date = BusinessDays.add(date, days)
      milestones.create!(kind:, title:, position: index, committed_on: date, original_committed_on: date)
    end
  end

  def status_label = StatusCatalog.label(:sub_order, status)
end
