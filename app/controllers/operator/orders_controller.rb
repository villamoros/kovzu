module Operator
  class OrdersController < BaseController
    def show
      @order = Order.includes(:client_company, :requirement, sub_orders: [ :category, :workshop, :milestones, :tech_sheets, { quotes: :workshop } ])
                    .find_by!(code: params[:id])
      @events = @order.audit_events.limit(20)
    end
  end
end
