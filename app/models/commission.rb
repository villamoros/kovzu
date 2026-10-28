# Comisión que el taller le paga a KOVZU. Se causa al registrar el saldo (RN-08) y se cobra en el corte mensual (RN-09).
class Commission < ApplicationRecord
  DELINQUENT_DAYS = 15

  enum :status, StatusCatalog.enum_for(:commission), default: "causada", validate: true

  belongs_to :workshop
  belongs_to :sub_order
  belongs_to :payment, optional: true
  belongs_to :commission_cut, optional: true

  validates :base_cop, :amount_cop, numericality: { only_integer: true, greater_than: 0 }
  validates :percent, numericality: { greater_than: 0, less_than_or_equal_to: 100 }
  validates :accrued_on, presence: true
  validates :invoice_number, :invoiced_on, :due_on, presence: true, if: -> { facturada? || pagada? }
  validates :sub_order_id, uniqueness: { conditions: -> { where.not(status: "anulada") }, message: "ya tiene una comisión causada" }

  scope :active, -> { where.not(status: "anulada") }
  scope :uncut, -> { causada.where(commission_cut_id: nil) }
  scope :delinquent, -> { facturada.where(due_on: ...DELINQUENT_DAYS.days.ago.to_date) }

  delegate :order, to: :sub_order

  # RN-08: porcentaje del convenio sobre el valor del taller antes de IVA.
  def self.accrue!(payment)
    sub_order = payment.sub_order
    workshop = sub_order.workshop
    base = sub_order.amount_cop.to_i
    percent = workshop.commission_percent
    create!(workshop:, sub_order:, payment:, base_cop: base, percent:, amount_cop: (base * percent / 100).round, accrued_on: payment.paid_on)
  end

  def days_overdue = facturada? && due_on ? (Date.current - due_on).to_i : 0

  def delinquent? = days_overdue > DELINQUENT_DAYS

  # Cartera de HU-20: causada, facturada (al día o vencida hasta 15 días), en mora o pagada.
  def bucket
    return :en_mora if delinquent?

    status.to_sym
  end

  def status_label = delinquent? ? "En mora" : StatusCatalog.label(:commission, status)
  def status_tone = delinquent? ? :danger : StatusCatalog.fetch(:commission, status)[:tone]
end
