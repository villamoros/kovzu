# Datos del tablero operativo (HU-25): pedidos por estado y lo que requiere atención primero.
class OperatorDashboard
  Attention = Data.define(:order, :reason, :tone, :due_on)

  attr_reader :filters

  def initialize(filters = {})
    @filters = filters.to_h.symbolize_keys.slice(:workshop_id, :category_id, :client_company_id).compact_blank
  end

  def orders
    @orders ||= begin
      scope = Order.open.includes(:client_company, sub_orders: [ :workshop, :category, :milestones ])
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
    order.sub_orders.flat_map do |sub_order|
      items = sub_order.milestones.select(&:late?).map do |milestone|
        Attention.new(order:, reason: "#{milestone.title} atrasado", tone: :danger, due_on: milestone.committed_on)
      end
      if sub_order.inspeccion?
        items << Attention.new(order:, reason: "Inspección pendiente", tone: :warning, due_on: milestone_date(sub_order, "inspeccion"))
      end
      if sub_order.muestra_pendiente? && items.none?
        due = milestone_date(sub_order, "muestra")
        items << Attention.new(order:, reason: "Muestra sin respuesta", tone: :warning, due_on: due) if due && due <= BusinessDays.add(Date.current, Milestone::ALERT_BUSINESS_DAYS)
      end
      items
    end
  end

  def milestone_date(sub_order, kind)
    sub_order.milestones.find { |milestone| milestone.kind == kind }&.committed_on
  end
end
