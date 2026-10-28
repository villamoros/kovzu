module Operator
  # RN-06: decisión tras el segundo rechazo del lote y devolución del anticipo del taller que falló (RN-05).
  class EscalationsController < BaseController
    NOTICES = {
      "reasignar" => "Subpedido reasignado. Elige otra cotización o pide nuevas; %{workshop} debe devolver el anticipo.",
      "descuento" => "Le enviamos el descuento al cliente. El subpedido sigue escalado hasta su respuesta.",
      "cancelar" => "Subpedido cancelado. %{workshop} debe devolver el anticipo."
    }.freeze

    def create
      sub_order = SubOrder.includes(:order, :workshop).find(params[:sub_order_id])
      attrs = params.expect(escalation: %i[decision reason discount_cop fee_refunded])
      escalation = Escalation.decide!(sub_order, decision: attrs[:decision], reason: attrs[:reason], discount_cop: attrs[:discount_cop],
                                                 fee_refunded: attrs[:fee_refunded], by: actor_name)
      redirect_to operator_order_path(sub_order.order), notice: format(NOTICES[escalation.decision], workshop: escalation.workshop.name)
    end

    def refund
      escalation = Escalation.includes(:workshop, sub_order: :order).find(params[:id])
      escalation.register_refund!(received_on: params[:received_on], by: actor_name)
      redirect_back_or_to operator_order_path(escalation.order), notice: "Registramos la devolución del anticipo de #{escalation.workshop.name}."
    end
  end
end
