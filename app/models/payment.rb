# Anticipo o saldo que el cliente le paga al taller, registrado con su soporte (HU-19, RF-28).
# Un pago no se borra: se anula con un motivo.
class Payment < ApplicationRecord
  class TransitionError < ::TransitionError; end
  class AmountMismatch < TransitionError; end

  KINDS = { "anticipo" => "Anticipo", "saldo" => "Saldo" }.freeze
  SUPPORT_TYPES = (Sample::PHOTO_TYPES + %w[application/pdf]).freeze

  enum :status, StatusCatalog.enum_for(:payment), default: "vigente", validate: true

  belongs_to :sub_order
  has_one :commission, -> { where.not(status: "anulada") }, inverse_of: :payment
  has_one_attached :support

  validates :kind, inclusion: { in: KINDS.keys }
  validates :amount_cop, numericality: { only_integer: true, greater_than: 0 }
  validates :paid_on, presence: true
  validates :support, presence: { message: "es obligatorio: adjunta la captura o el PDF de la transferencia" }
  validate :support_type
  validate :paid_on_not_in_future

  before_destroy { throw :abort }

  delegate :order, :workshop, to: :sub_order

  # Acepta valores escritos con puntos de miles ("1.450.000").
  def amount_cop=(value)
    super(value.is_a?(String) ? value.gsub(/\D/, "").presence : value)
  end

  def anticipo? = kind == "anticipo"
  def saldo? = kind == "saldo"

  def kind_label = KINDS[kind]
  def status_label = StatusCatalog.label(:payment, status)

  def mismatch? = expected_cop.present? && amount_cop.present? && amount_cop != expected_cop

  def difference_cop = amount_cop.to_i - expected_cop.to_i

  # Anula el pago. Si era el saldo, también anula la comisión que causó, si aún no se facturó.
  def void!(reason, by:)
    raise TransitionError, "Escribe el motivo de la anulación." if reason.blank?

    with_lock do
      raise TransitionError, "Este pago ya está anulado." if anulado?
      if commission && !commission.causada?
        raise TransitionError, "La comisión de este saldo ya está #{commission.status_label.downcase}. Corrígela en la cartera antes de anular."
      end

      update!(status: "anulado", void_reason: reason, voided_by: by, voided_at: Time.current)
      commission&.update!(status: "anulada", void_reason: "Saldo anulado: #{reason}")
      sub_order.reopen_after_void!(self)
      AuditEvent.record!(sub_order, "pago.anulado", actor: by, data: { kind:, amount_cop:, reason: })
    end
  end

  private

  def support_type
    return unless support.attached?
    return if support.content_type.in?(SUPPORT_TYPES)

    errors.add(:support, "debe ser una foto o un PDF")
  end

  def paid_on_not_in_future
    errors.add(:paid_on, "no puede ser una fecha futura") if paid_on.present? && paid_on > Date.current
  end
end
