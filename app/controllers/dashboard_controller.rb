# Inicio del cliente: lo que espera su respuesta, sus pedidos y sus requerimientos.
class DashboardController < Portal::BaseController
  def show
    @orders = current_company.orders.open.includes(:proposals, sub_orders: %i[milestones samples]).order(created_at: :desc)
    @requirements = current_company.requirements.where(status: %w[en_revision esperando_cliente]).order(submitted_at: :desc)
    @proposals = Proposal.enviada.where(order: current_company.orders).includes(:order)
    @samples = Sample.por_revisar.joins(:sub_order).where(sub_orders: { order_id: current_company.orders.select(:id) }).includes(sub_order: :order)
    @questions = @requirements.select(&:esperando_cliente?)
  end
end
