# Datos del tablero operativo (HU-25): pedidos por estado y lo que requiere atención primero.
class OperatorDashboard
  Attention = Data.define(:order, :reason, :tone, :due_on)

  attr_reader :filters

  def initialize(filters = {})
    @filters = filters.to_h.symbolize_keys.slice(:workshop_id, :category_id, :client_company_id).compact_blank
  end

  def orders
    @orders ||= begin
      scope = Order.open.includes(:client_company, proposals: :quote, sub_orders: [ :workshop, :category, :milestones, :samples, :inspections, :payments, :quotes, :escalations ])
      scope = scope.where(id: SubOrder.where(workshop_id: filters[:workshop_id]).select(:order_id)) if filters[:workshop_id]
      scope = scope.where(id: SubOrder.where(category_id: filters[:category_id]).select(:order_id)) if filters[:category_id]
      scope = scope.where(client_company_id: filters[:client_company_id]) if filters[:client_company_id]
      scope.order(created_at: :desc).to_a
    end
  end

  def counts_by_status
    orders.group_by(&:status).transform_values(&:size)
  end

  # Atrasos, inspecciones pendientes y muestras sin respuesta (HU-25), lo más urgente primero.
  def attention
    @attention ||= orders.flat_map { |order| attention_for(order) }.sort_by { |item| [ item.tone == :danger ? 0 : 1, item.due_on || Date.current ] }
  end

  def attention_orders = attention.map(&:order).uniq

  def other_orders = orders - attention_orders

  def requirements_in_queue = Requirement.in_queue.includes(:client_company, :category)

  def quotes_waiting = Quote.solicitada.includes(:workshop, sub_order: :order).order(:created_at)

  # RN-09 / HU-20: talleres con comisiones facturadas y más de 15 días de mora.
  def delinquent_workshops = Workshop.delinquent.order(:name)

  def filtered? = filters.any?

  # RN-05: anticipos que un taller debe devolver tras una reasignación o cancelación (RN-06).
  def refunds_pending = Escalation.refund_pending.includes(:workshop, sub_order: :order).order(:created_at)

  private

  def attention_for(order)
    proposal_attention(order) + order.sub_orders.flat_map do |sub_order|
      items = sub_order.milestones.select(&:late?).map do |milestone|
        Attention.new(order:, reason: "#{milestone.title} atrasado", tone: :danger, due_on: milestone.committed_on)
      end
      if sub_order.inspeccion?
        items << Attention.new(order:, reason: "Inspección pendiente", tone: :warning, due_on: milestone_date(sub_order, "inspeccion"))
      end
      items.concat(quality_attention(order, sub_order))
      if sub_order.quotes.any? { |quote| quote.solicitada? && quote.renewal_requested_at }
        items << Attention.new(order:, reason: "Un taller pidió un enlace nuevo para cotizar", tone: :warning, due_on: nil)
      end
      if sub_order.rejection_count >= Sample::REJECTIONS_ALERT
        items << Attention.new(order:, reason: "#{sub_order.rejection_count} muestras rechazadas: revisar ficha o taller", tone: :danger, due_on: nil)
      end
      sample = sub_order.samples.last
      if sample&.overdue?
        items << Attention.new(order:, reason: "Cliente sin responder la muestra", tone: :warning, due_on: sample.created_at.to_date)
      elsif sub_order.muestra_pendiente? && items.none? && sample.nil?
        due = milestone_date(sub_order, "muestra")
        items << Attention.new(order:, reason: "Muestra sin registrar", tone: :warning, due_on: due) if due && due <= BusinessDays.add(Date.current, Milestone::ALERT_BUSINESS_DAYS)
      end
      items
    end
  end

  # HU-07: el cliente pidió cambios, o la cotización de la propuesta venció.
  def proposal_attention(order)
    proposal = order.proposals.reject(&:reemplazada?).last
    return [] unless proposal

    if proposal.cambios_solicitados?
      [ Attention.new(order:, reason: "El cliente pidió cambios a la propuesta", tone: :warning, due_on: proposal.decided_at&.to_date) ]
    elsif proposal.enviada? && proposal.quote_expired?
      [ Attention.new(order:, reason: "Venció la cotización de la propuesta", tone: :danger, due_on: proposal.quote.valid_until) ]
    else
      []
    end
  end

  # HU-13 / HU-19: desviación sin respuesta, segundo rechazo (RN-06) y saldo habilitado sin registrar.
  def quality_attention(order, sub_order)
    inspection = sub_order.inspections.last
    if sub_order.escalado? && sub_order.escalations.any?(&:esperando_cliente?)
      [ Attention.new(order:, reason: "Descuento esperando la respuesta del cliente", tone: :warning, due_on: sub_order.escalations.last.created_at.to_date) ]
    elsif sub_order.escalado?
      [ Attention.new(order:, reason: "Segundo rechazo del lote: decidir reasignar, descontar o cancelar", tone: :danger, due_on: inspection&.closed_at&.to_date) ]
    elsif sub_order.aprobado_con_desviacion?
      [ Attention.new(order:, reason: "Desviación esperando la decisión del cliente", tone: :warning, due_on: inspection&.closed_at&.to_date) ]
    elsif sub_order.aprobado? && sub_order.payments.none? { |payment| payment.vigente? && payment.kind == "saldo" }
      [ Attention.new(order:, reason: "Saldo habilitado sin registrar", tone: :warning, due_on: inspection&.closed_at&.to_date) ]
    else
      []
    end
  end

  def milestone_date(sub_order, kind)
    sub_order.milestones.find { |milestone| milestone.kind == kind }&.committed_on
  end
end
