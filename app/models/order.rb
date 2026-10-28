# Pedido del cliente. Agrupa uno o varios subpedidos y tiene una sola fecha de entrega.
class Order < ApplicationRecord
  KINDS = { "simple" => "Simple", "multi_taller" => "Multi-taller", "inspeccion_planta" => "Con inspección en planta" }.freeze
  CLOSED = %w[entregado cancelado].freeze

  enum :status, StatusCatalog.enum_for(:order), default: "en_preparacion", validate: true

  belongs_to :client_company
  belongs_to :requirement, optional: true
  has_many :sub_orders, -> { order(:id) }, dependent: :destroy, inverse_of: :order
  has_many :milestones, through: :sub_orders
  has_many :proposals, -> { order(:created_at) }, dependent: :destroy
  has_many :audit_events, -> { order(created_at: :desc) }, dependent: :destroy

  validates :code, presence: true, uniqueness: true
  validates :kind, inclusion: { in: KINDS.keys }
  validates :management_fee_cop, numericality: { greater_than: 0 }, allow_nil: true

  before_validation :assign_code, on: :create

  scope :open, -> { where.not(status: CLOSED) }

  # Requerimiento completo → pedido en preparación con su subpedido y la ficha v1 (HU-03).
  def self.start_from!(requirement, by:)
    raise Requirement::TransitionError, "El requerimiento debe estar completo y sin pedido." unless requirement.can_start_order?

    transaction do
      order = create!(client_company: requirement.client_company, requirement:)
      sub_order = order.sub_orders.create!(category: requirement.category, title: requirement.title, quantity: requirement.quantity)
      TechSheet.build_from(requirement, sub_order).save!
      AuditEvent.record!(order, "pedido.creado", actor: by, data: { requirement_id: requirement.id })
      order
    end
  end

  def current_proposal = proposals.reject(&:reemplazada?).last

  def to_param = code

  def title = sub_orders.first&.title || requirement&.title

  def late_milestones = milestones.late

  def late? = late_milestones.exists?

  def status_label = StatusCatalog.label(:order, status)

  private

  def assign_code
    return if code.present?

    last = Order.maximum(Arel.sql("CAST(SUBSTRING(code FROM 4) AS INTEGER)")) || 0
    self.code = format("KZ-%04d", last + 1)
  end
end
