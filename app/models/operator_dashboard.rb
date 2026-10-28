# Datos del tablero operativo (HU-25): pedidos por estado y lo que requiere atención primero.
class OperatorDashboard
  Attention = Data.define(:order, :reason, :tone, :due_on)

  attr_reader :filters

  def initialize(filters = {})
    @filters = filters.to_h.symbolize_keys.slice(:workshop_id, :category_id, :client_company_id).compact_blank
  end

  def orders
    @orders ||= begin
      scope = Order.open.includes(:client_company, proposals: :quote, sub_orders: [ :workshop, :category, :milestones, :samples ])
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

  def filtered? = filters.any?

  private

  def attention_for(order)
    proposal_attention(order) + order.sub_orders.flat_map do |sub_order|
      items = sub_order.milestones.select(&:late?).map do |milestone|
        Attention.new(order:, reason: "#{milestone.title} atrasado", tone: :danger, due_on: milestone.committed_on)
      end
      if sub_order.inspeccion?
        items << Attention.new(order:, reason: "Inspección pendiente", tone: :warning, due_on: milestone_date(sub_order, "inspeccion"))
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

  def milestone_date(sub_order, kind)
    sub_order.milestones.find { |milestone| milestone.kind == kind }&.committed_on
  end
end
