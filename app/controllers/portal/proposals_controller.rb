module Portal
  # HU-07: el cliente revisa la propuesta y la acepta o pide cambios.
  class ProposalsController < BaseController
    before_action :set_proposal

    def show
    end

    def accept
      @proposal.accept!(user: current_user)
      redirect_to order_path(@order), notice: "Pedido confirmado. El siguiente paso es el anticipo al taller."
    end

    def request_changes
      @proposal.request_changes!(params[:comment], user: current_user)
      redirect_to order_path(@order), notice: "Le enviamos tus comentarios a KOVZU. Te escribimos con la propuesta ajustada."
    end

    private

    def set_proposal
      @order = current_company.orders.find_by!(code: params[:order_id])
      @proposal = @order.current_proposal or raise ActiveRecord::RecordNotFound
    end
  end
end
