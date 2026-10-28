# Cotización de un taller para un subpedido. El taller responde por un enlace sin contraseña (HU-05).
class Quote < ApplicationRecord
  class TransitionError < ::TransitionError; end

  enum :status, StatusCatalog.enum_for(:quote), default: "solicitada", validate: true

  belongs_to :sub_order
  belongs_to :workshop
  belongs_to :tech_sheet

  has_secure_token :token, length: 32
  has_one_attached :support

  validates :workshop_id, uniqueness: { scope: :sub_order_id, message: "ya tiene una solicitud para este subpedido" }
  validates :price_cop, numericality: { greater_than: 0 }, allow_nil: true
  validates :lead_days, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :price_cop, :lead_days, presence: true, if: -> { recibida? || elegida? }
  validate :workshop_can_quote, on: :create

  scope :received, -> { where(status: %w[recibida elegida no_elegida]) }

  def link_expired? = link_expires_at.past?

  def offer_expired? = valid_until.present? && valid_until < Date.current

  def status_label = StatusCatalog.label(:quote, status)

  def answered? = !solicitada?

  # HU-05: cotización que llegó por WhatsApp; el operador la carga con el soporte.
  def record_by_operator!(attrs, support:, by:)
    raise TransitionError, "Esta cotización ya fue respondida." if answered?
    raise TransitionError, "Adjunta el soporte (captura o PDF) de la cotización." if support.blank?

    attrs = attrs.to_h.symbolize_keys.slice(:price_cop, :lead_days, :conditions, :valid_until)
    raise TransitionError, "Precio y plazo son obligatorios." if attrs[:price_cop].blank? || attrs[:lead_days].blank?

    transaction do
      update!(**attrs, support:, status: "recibida", entered_by_operator: true, submitted_at: Time.current)
      AuditEvent.record!(self, "cotizacion.recibida", actor: by, data: { workshop: workshop.name, por_operador: true })
    end
  end

  # El taller no cotiza; queda el motivo para el operador.
  def decline!(reason, by:)
    raise TransitionError, "Esta cotización ya fue respondida." if answered?
    raise TransitionError, "Escribe el motivo." if reason.blank?

    update!(status: "rechazada", decline_reason: reason, submitted_at: Time.current)
    AuditEvent.record!(self, "cotizacion.rechazada", actor: by, data: { workshop: workshop.name })
  end

  private

  # RN-01: solo talleres verificados con capacidad en la categoría.
  def workshop_can_quote
    return if workshop.nil? || sub_order.nil?

    errors.add(:workshop, "debe estar verificado para cotizar") unless workshop.verificado?
    return if workshop.capabilities.exists?(category_id: sub_order.category_id)

    errors.add(:workshop, "no tiene capacidad registrada en #{sub_order.category.name}")
  end
end
