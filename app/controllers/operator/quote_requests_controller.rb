module Operator
  # Solicitud de cotización a 1–3 talleres (HU-04).
  class QuoteRequestsController < BaseController
    before_action :set_sub_order

    def new
      @candidates = Workshop.candidates_for(@sub_order).includes(:capabilities).to_a
      @requested_ids = @sub_order.quotes.pluck(:workshop_id)
      @not_verified = Workshop.where.not(status: "verificado").joins(:capabilities)
                              .where(workshop_capabilities: { category_id: @sub_order.category_id }).distinct.count
    end

    def create
      quotes = @sub_order.request_quotes!(params[:workshop_ids], by: actor_name)
      redirect_to operator_order_path(@sub_order.order),
                  notice: "Solicitud enviada a #{quotes.map { |quote| quote.workshop.name }.to_sentence}. Cada enlace vence en 5 días."
    end

    private

    def set_sub_order
      @sub_order = SubOrder.includes(:order, :category).find(params[:sub_order_id])
      @tech_sheet = @sub_order.current_tech_sheet
    end
  end
end
