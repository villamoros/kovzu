module Portal
  # RN-06: el cliente acepta o rechaza el descuento que KOVZU propone tras el segundo rechazo del lote.
  class EscalationsController < BaseController
    before_action :set_escalation

    def accept
      @escalation.accept_discount!(user: current_user)
      redirect_to order_path(@order), notice: "Aceptaste el descuento. Ya puedes pagar el saldo al taller."
    end

    def reject
      @escalation.reject_discount!(params[:comment], user: current_user)
      redirect_to order_path(@order), notice: "Registramos tu respuesta. El equipo de KOVZU te propone otra salida."
    end

    private

    def set_escalation
      @order = current_company.orders.find_by!(code: params[:order_id])
      @escalation = Escalation.where(sub_order_id: @order.sub_orders.select(:id)).find(params[:id])
    end
  end
end
