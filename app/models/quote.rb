# Cotización de un taller para un subpedido. El taller responde por un enlace sin contraseña (HU-05).
class Quote < ApplicationRecord
  enum :status, StatusCatalog.enum_for(:quote), default: "solicitada", validate: true

  belongs_to :sub_order
  belongs_to :workshop
  belongs_to :tech_sheet

  has_secure_token :token, length: 32

  validates :workshop_id, uniqueness: { scope: :sub_order_id, message: "ya tiene una solicitud para este subpedido" }
  validates :price_cop, numericality: { greater_than: 0 }, allow_nil: true
  validates :lead_days, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validate :workshop_can_quote, on: :create

  def link_expired? = link_expires_at.past?

  def offer_expired? = valid_until.present? && valid_until < Date.current

  def status_label = StatusCatalog.label(:quote, status)

  private

  # RN-01: solo talleres verificados con capacidad en la categoría.
  def workshop_can_quote
    return if workshop.nil? || sub_order.nil?

    errors.add(:workshop, "debe estar verificado para cotizar") unless workshop.verificado?
    return if workshop.capabilities.exists?(category_id: sub_order.category_id)

    errors.add(:workshop, "no tiene capacidad registrada en #{sub_order.category.name}")
  end
end
