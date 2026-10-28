module Portal
  # HU-13: el cliente ve el acta y, si hay una desviación, la acepta o la rechaza antes de pagar el saldo.
  class InspectionsController < BaseController
    before_action :set_inspection

    def show
    end

    def accept_deviation
      @inspection.accept_deviation!(user: current_user)
      redirect_to order_path(@order), notice: "Aceptaste la desviación. Ya puedes pagar el saldo al taller."
    end

    def reject_deviation
      @inspection.reject_deviation!(params[:comment], user: current_user)
      redirect_to order_path(@order), notice: "Registramos tu decisión. El taller reprocesa el lote a su costo y lo volvemos a inspeccionar."
    end

    private

    def set_inspection
      @order = current_company.orders.find_by!(code: params[:order_id])
      @inspection = Inspection.cerrada.includes(items: { photos_attachments: :blob }, sub_order: [ :category, :workshop ])
                              .where(sub_order_id: @order.sub_orders.select(:id)).find(params[:id])
    end
  end
end
