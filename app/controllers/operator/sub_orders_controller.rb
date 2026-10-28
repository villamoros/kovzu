module Operator
  # Avances del subpedido que dispara el operador: producción terminada (CU-07) y entrega.
  class SubOrdersController < BaseController
    before_action :set_sub_order

    def finish_production
      @sub_order.finish_production!(by: actor_name)
      redirect_to operator_order_path(@sub_order.order), notice: "#{@sub_order.title} quedó listo para inspección."
    end

    def deliver
      @sub_order.deliver!(by: actor_name)
      redirect_to operator_order_path(@sub_order.order), notice: "Entrega registrada. Le avisamos al cliente."
    end

    private

    def set_sub_order
      @sub_order = SubOrder.includes(:order).find(params[:id])
    end
  end
end
