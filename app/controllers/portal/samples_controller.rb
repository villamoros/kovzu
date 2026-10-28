module Portal
  # HU-09: aprobar o rechazar la muestra con comentarios.
  class SamplesController < BaseController
    before_action :set_sample

    def approve
      @sample.approve!(user: current_user)
      redirect_to order_path(@sample.order), notice: "Muestra aprobada. El taller arranca la producción."
    end

    def reject
      @sample.reject!(params[:comment], user: current_user)
      redirect_to order_path(@sample.order), notice: "Le pasamos tus comentarios al taller. Te avisamos cuando haya una nueva muestra."
    end

    private

    def set_sample
      @sample = Sample.joins(:sub_order).where(sub_orders: { order_id: current_company.orders.select(:id) }).find(params[:id])
    end
  end
end
