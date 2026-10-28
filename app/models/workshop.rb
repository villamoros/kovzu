# Taller de la red. Solo los verificados reciben solicitudes de cotización (RN-01).
class Workshop < ApplicationRecord
  class TransitionError < ::TransitionError; end

  LEVELS = { "verificado" => "Verificado", "confiable" => "Confiable", "preferente" => "Preferente" }.freeze

  # Checklist de la visita de verificación (HU-16). RUT y factura electrónica son columnas propias.
  VISIT_ITEMS = {
    "maquinas" => "Máquinas y capacidad revisadas",
    "fotos" => "Fotos de trabajos anteriores",
    "visita" => "Visita a la planta realizada"
  }.freeze

  enum :status, StatusCatalog.enum_for(:workshop), default: "prospecto", validate: true

  has_many :capabilities, class_name: "WorkshopCapability", dependent: :destroy, inverse_of: :workshop
  has_many :categories, through: :capabilities
  has_many :quotes, dependent: :restrict_with_error
  has_many :sub_orders, dependent: :restrict_with_error
  has_many :audit_events, as: :subject, dependent: :destroy
  has_many :commissions, dependent: :restrict_with_error

  accepts_nested_attributes_for :capabilities, allow_destroy: true, reject_if: ->(attrs) { attrs["category_id"].blank? }

  validates :name, presence: true
  validates :level, inclusion: { in: LEVELS.keys }, allow_nil: true
  validates :nit, uniqueness: true, allow_blank: true
  validates :score, numericality: { in: 0..5 }, allow_nil: true
  validates :commission_percent, numericality: { in: 8..12, message: "debe estar entre 8 % y 12 % (convenio)" }
  validate :verified_requires_rut_and_invoicing

  normalizes :nit, with: ->(nit) { nit.strip.presence }

  # RN-09: una mora de más de 15 días en comisiones pausa las asignaciones.
  scope :delinquent, -> { where(id: Commission.delinquent.select(:workshop_id)) }
  scope :eligible_for_quotes, -> { verificado.where.not(id: Commission.delinquent.select(:workshop_id)) }
  scope :ranked, lambda {
    order(Arel.sql("CASE workshops.level WHEN 'preferente' THEN 0 WHEN 'confiable' THEN 1 ELSE 2 END"),
          Arel.sql("workshops.score DESC NULLS LAST"), :name)
  }

  # Talleres que pueden cotizar un subpedido: verificados, con la categoría y el volumen (HU-04).
  def self.candidates_for(sub_order)
    scope = eligible_for_quotes.joins(:capabilities).where(workshop_capabilities: { category_id: sub_order.category_id })
    if (quantity = sub_order.quantity)
      scope = scope.where("workshop_capabilities.min_volume IS NULL OR workshop_capabilities.min_volume <= ?", quantity)
                   .where("workshop_capabilities.max_volume IS NULL OR workshop_capabilities.max_volume >= ?", quantity)
    end
    scope.ranked
  end

  def visit_checklist=(value)
    items = value.to_h.stringify_keys.slice(*VISIT_ITEMS.keys)
    super(items.transform_values { |checked| ActiveModel::Type::Boolean.new.cast(checked) || false })
  end

  def visit_item?(key) = visit_checklist[key.to_s] == true

  def missing_for_verification
    missing = []
    missing << "RUT activo" unless has_rut?
    missing << "Factura electrónica" unless e_invoicing?
    missing + VISIT_ITEMS.reject { |key, _| visit_item?(key) }.values
  end

  def checklist_complete? = missing_for_verification.empty?

  # Prospecto → En verificación, con el checklist completo.
  def start_verification!(by:)
    raise TransitionError, "Solo un prospecto puede pasar a verificación." unless prospecto?
    raise TransitionError, "Falta en el checklist: #{missing_for_verification.to_sentence}." unless checklist_complete?

    transition!("en_verificacion", by:, visited_at: visited_at || Time.current)
  end

  # En verificación → Verificado, con un pedido piloto conforme (RN-02: exige RUT y factura electrónica).
  def approve_pilot!(by:)
    raise TransitionError, "El taller debe estar en verificación." unless en_verificacion?
    raise TransitionError, "No se puede verificar sin RUT activo y factura electrónica." unless has_rut? && e_invoicing?

    transition!("verificado", by:, level: level || "verificado", pilot_approved_at: Time.current)
  end

  def pause!(reason:, by:)
    raise TransitionError, "Escribe el motivo de la pausa." if reason.blank?
    raise TransitionError, "Solo se pausa un taller verificado." unless verificado?

    transition!("pausado", by:, status_reason: reason)
  end

  def resume!(by:)
    raise TransitionError, "El taller no está pausado." unless pausado?

    transition!("verificado", by:, status_reason: nil)
  end

  def retire!(reason:, by:)
    raise TransitionError, "Escribe el motivo del retiro." if reason.blank?
    raise TransitionError, "El taller ya está retirado." if retirado?

    transition!("retirado", by:, status_reason: reason)
  end

  def delinquent? = commissions.delinquent.exists?

  def level_label = LEVELS[level]
  def status_label = StatusCatalog.label(:workshop, status)

  private

  def transition!(new_status, by:, **attrs)
    from = status
    transaction do
      update!(status: new_status, **attrs)
      AuditEvent.record!(self, "taller.#{new_status}", actor: by, data: { from:, reason: attrs[:status_reason] }.compact)
    end
  end

  def verified_requires_rut_and_invoicing
    return unless verificado? && !(has_rut? && e_invoicing?)

    errors.add(:status, "verificado exige RUT activo y factura electrónica")
  end
end
