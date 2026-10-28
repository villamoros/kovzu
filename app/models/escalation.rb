# RN-06 / HU-15: tras el segundo rechazo del lote, el operador decide reasignar, negociar un descuento o cancelar.
# Cada decisión exige un motivo. El taller que falló devuelve el anticipo (RN-05).
class Escalation < ApplicationRecord
  class TransitionError < ::TransitionError; end

  DECISIONS = {
    "reasignar" => "Reasignar a otro taller",
    "descuento" => "Negociar un descuento",
    "cancelar" => "Cancelar el subpedido"
  }.freeze
  PENDING_DISCOUNT = "Ya hay un descuento esperando la respuesta del cliente.".freeze

  enum :status, StatusCatalog.enum_for(:escalation), default: "aplicada", validate: true

  belongs_to :sub_order
  belongs_to :workshop
  has_many :approvals, as: :approvable, dependent: :restrict_with_error

  validates :decision, inclusion: { in: DECISIONS.keys }
  validates :reason, presence: { message: "es obligatorio: explica por qué" }
  validates :discount_cop, numericality: { only_integer: true, greater_than: 0 }, if: :descuento?

  scope :refund_pending, -> { where(refund_received_on: nil).where("refund_cop > 0") }

  delegate :order, to: :sub_order

  # Valores escritos con puntos de miles ("150.000").
  def discount_cop=(value)
    super(value.is_a?(String) ? value.gsub(/\D/, "").presence : value)
  end

  def decision_label = DECISIONS[decision]
  def reasignar? = decision == "reasignar"
  def descuento? = decision == "descuento"
  def cancelar? = decision == "cancelar"
  def status_label = StatusCatalog.label(:escalation, status)

  def refund_pending? = refund_cop.to_i.positive? && refund_received_on.nil?

  # El operador decide. Reasignar y cancelar se aplican de una vez; el descuento espera al cliente.
  # Bloquea el subpedido: dos operadores que deciden a la vez no aplican dos salidas.
  def self.decide!(sub_order, decision:, reason:, by:, discount_cop: nil, fee_refunded: false)
    escalation = sub_order.with_lock do
      raise TransitionError, "El subpedido no está escalado." unless sub_order.escalado?
      raise TransitionError, PENDING_DISCOUNT if sub_order.escalations.esperando_cliente.exists?

      escalation = sub_order.escalations.build(decision:, reason:, decided_by: by, workshop: sub_order.workshop,
                                               discount_cop: (discount_cop if decision == "descuento"),
                                               fee_refunded: decision == "cancelar" && ActiveModel::Type::Boolean.new.cast(fee_refunded).present?)
      escalation.validate!
      escalation.check_discount!

      escalation.save!
      escalation.send(:"apply_#{decision}!", by)
      AuditEvent.record!(sub_order.order, "pedido.escalado_#{decision}", actor: by,
                         data: { sub_order: sub_order.title, workshop: escalation.workshop.name, reason:, discount_cop: escalation.discount_cop }.compact)
      escalation
    end
    escalation.notify_client
    escalation
  rescue ActiveRecord::RecordNotUnique
    raise TransitionError, PENDING_DISCOUNT
  end

  # El cliente acepta el descuento: el lote se recibe y el saldo baja.
  def accept_discount!(user:)
    with_lock do
      raise TransitionError, "Este descuento ya no espera tu respuesta." unless esperando_cliente?

      approvals.create!(decision: "aceptada", actor_role: "cliente", actor_name: user.name, user:, comment: "Descuento de #{discount_cop}")
      update!(status: "aplicada", client_decided_by: user.name, client_decided_at: Time.current)
      sub_order.update!(status: "aprobado", discount_cop:)
      sub_order.milestones.find_by(kind: "inspeccion")&.complete!
      order.update!(status: "en_curso") if order.escalado?
      AuditEvent.record!(order, "pedido.descuento_aceptado", actor: user.name, data: { sub_order: sub_order.title, discount_cop: })
    end
    ClientMailer.with(sub_order:).balance_enabled.deliver_later
  end

  # El cliente no acepta: el subpedido sigue escalado y el operador decide otra salida.
  def reject_discount!(comment, user:)
    raise TransitionError, "Cuéntanos por qué no aceptas el descuento." if comment.blank?

    with_lock do
      raise TransitionError, "Este descuento ya no espera tu respuesta." unless esperando_cliente?

      approvals.create!(decision: "rechazada", actor_role: "cliente", actor_name: user.name, user:, comment:)
      update!(status: "rechazada", client_comment: comment, client_decided_by: user.name, client_decided_at: Time.current)
      AuditEvent.record!(order, "pedido.descuento_rechazado", actor: user.name, data: { sub_order: sub_order.title })
    end
  end

  def register_refund!(received_on:, by:)
    raise TransitionError, "No hay devolución pendiente." unless refund_pending?

    received_on = (received_on.presence || Date.current).to_date
    raise TransitionError, "La fecha no puede ser futura." if received_on > Date.current

    update!(refund_received_on: received_on)
    AuditEvent.record!(order, "pedido.anticipo_devuelto", actor: by, data: { workshop: workshop.name, refund_cop: })
  end

  def check_discount!
    return unless descuento?

    balance = sub_order.expected_payment_cop(:saldo)
    raise TransitionError, "El descuento debe ser menor que el saldo (#{ActiveSupport::NumberHelper.number_to_delimited(balance, delimiter: '.')})." if discount_cop >= balance
  end

  def notify_client
    headline, body = case decision
    when "reasignar" then [ "Reasignamos #{sub_order.title}", "El lote no pasó la reinspección. Lo vamos a fabricar con otro taller verificado y te enviamos una nueva propuesta." ]
    when "descuento" then [ "Te proponemos un descuento en #{sub_order.title}", "El lote no pasó la reinspección. Te ofrecemos recibirlo con un descuento. Revisa la propuesta en tu pedido." ]
    else [ "Cancelamos #{sub_order.title}", "El lote no pasó la reinspección y cancelamos este subpedido. #{fee_refunded? ? 'Te devolvemos el fee de gestión.' : ''}".strip ]
    end
    ClientMailer.with(order:, headline:, body:).order_update.deliver_later
  end

  private

  # Nuevo taller: el anticipo del anterior se anula y queda por devolver; las cotizaciones vigentes vuelven a estar disponibles.
  def apply_reasignar!(by)
    withdraw_advance!(by)
    sub_order.quotes.elegida.update_all(status: "no_elegida", updated_at: Time.current)
    sub_order.quotes.no_elegida.where.not(workshop_id: workshop_id).find_each do |quote|
      quote.update!(status: "recibida", chosen_at: nil) unless quote.offer_expired?
    end
    order.proposals.where(status: "aceptada").find_each { |proposal| proposal.update_columns(status: "reemplazada", updated_at: Time.current) }
    sub_order.milestones.destroy_all
    sub_order.update!(status: "cotizando", workshop: nil, amount_cop: nil, discount_cop: 0, rejection_count: 0, reassigned_at: Time.current)
    order.update!(status: "cotizando")
  end

  def apply_descuento!(_by)
    update!(status: "esperando_cliente")
  end

  def apply_cancelar!(by)
    withdraw_advance!(by)
    sub_order.update!(status: "cancelado")
    open = order.sub_orders.reload.reject { |sub| sub.cancelado? || sub.entregado? }
    if open.empty?
      order.update!(status: order.sub_orders.all?(&:cancelado?) ? "cancelado" : "entregado")
    elsif order.escalado?
      order.update!(status: "en_curso")
    end
  end

  def withdraw_advance!(by)
    advance = sub_order.payment(:anticipo)
    return unless advance

    update!(refund_cop: advance.amount_cop)
    advance.update!(status: "anulado", voided_by: by, voided_at: Time.current,
                    void_reason: "#{decision_label}: #{workshop.name} debe devolver el anticipo")
  end
end
