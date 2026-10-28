# Cotización de un taller para un subpedido. El taller responde por un enlace sin contraseña (HU-05).
class Quote < ApplicationRecord
  class TransitionError < ::TransitionError; end

  enum :status, StatusCatalog.enum_for(:quote), default: "solicitada", validate: true

  belongs_to :sub_order
  belongs_to :workshop
  belongs_to :tech_sheet

  has_secure_token :token, length: 32
  has_one_attached :support
  has_many :approvals, as: :approvable, dependent: :restrict_with_error

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

  # El enlace sirve para responder solo si está vigente y la ficha sigue siendo la misma versión.
  def link_usable? = solicitada? && !link_expired? && !tech_sheet.reemplazada?

  # HU-05: el taller cotiza desde el enlace. Queda la versión de la ficha que aceptó y el enlace ya no edita.
  def submit_from_link!(attrs, accept_sheet:)
    raise TransitionError, "Ya enviaste esta cotización." if answered?
    raise TransitionError, "El enlace venció. Pide uno nuevo." if link_expired?
    raise TransitionError, "La ficha técnica cambió. Pide un enlace nuevo para cotizar la versión vigente." if tech_sheet.reemplazada?
    raise TransitionError, "Confirma que leíste y aceptas la ficha técnica v#{tech_sheet.version}." unless ActiveModel::Type::Boolean.new.cast(accept_sheet)

    attrs = attrs.to_h.symbolize_keys.slice(:price_cop, :lead_days, :conditions, :valid_until)
    assign_attributes(**attrs, status: "recibida", submitted_at: Time.current)
    valid?
    errors.add(:valid_until, "es obligatoria") if valid_until.blank?
    errors.add(:valid_until, "debe ser hoy o una fecha futura") if valid_until.present? && valid_until < Date.current
    raise ActiveRecord::RecordInvalid, self if errors.any?

    transaction do
      save!
      approvals.create!(decision: "aceptada", actor_role: "taller", actor_name: workshop.name, version: tech_sheet.version)
      AuditEvent.record!(self, "cotizacion.recibida", actor: workshop.name, data: { workshop: workshop.name, version: tech_sheet.version })
    end
  end

  # El enlace venció: el taller pide uno nuevo y el operador lo ve en el tablero.
  def request_renewal!
    raise TransitionError, "Esta solicitud ya fue respondida." if answered?
    return if renewal_requested_at.present?

    update!(renewal_requested_at: Time.current)
    AuditEvent.record!(self, "cotizacion.enlace_pedido", actor: workshop.name, data: { workshop: workshop.name })
  end

  # El operador renueva el enlace: token nuevo, vigencia nueva y la ficha vigente.
  def renew_link!(by:)
    raise TransitionError, "Esta solicitud ya fue respondida." if answered?

    sheet = sub_order.current_tech_sheet
    raise TransitionError, "La ficha técnica debe estar lista para renovar el enlace." unless sheet&.lista? || sheet&.aceptada?

    transaction do
      regenerate_token
      update!(link_expires_at: SubOrder::QUOTE_LINK_TTL.from_now, renewal_requested_at: nil, tech_sheet: sheet)
      AuditEvent.record!(self, "cotizacion.enlace_renovado", actor: by, data: { workshop: workshop.name })
    end
    WorkshopMailer.with(quote: self).quote_request.deliver_later if workshop.email.present?
  end

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
    errors.add(:workshop, "está en mora con comisiones y no recibe solicitudes (RN-09)") if workshop.delinquent?
    return if workshop.capabilities.exists?(category_id: sub_order.category_id)

    errors.add(:workshop, "no tiene capacidad registrada en #{sub_order.category.name}")
  end
end
