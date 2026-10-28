module Operator
  # HU-05: el operador carga la cotización que llegó por WhatsApp, o registra que el taller no cotiza.
  class QuotesController < BaseController
    before_action :set_quote

    def edit
    end

    def update
      @quote.record_by_operator!(params.expect(quote: %i[price_cop lead_days conditions valid_until]), support: params.dig(:quote, :support), by: actor_name)
      redirect_to operator_order_path(@quote.sub_order.order), notice: "Cotización de #{@quote.workshop.name} cargada."
    rescue Quote::TransitionError, ActiveRecord::RecordInvalid => error
      flash.now[:alert] = error.message
      render :edit, status: :unprocessable_entity
    end

    def decline
      @quote.decline!(params[:reason], by: actor_name)
      redirect_to operator_order_path(@quote.sub_order.order), notice: "Registramos que #{@quote.workshop.name} no cotiza."
    end

    private

    def set_quote
      @quote = Quote.includes(:workshop, :tech_sheet, sub_order: [ :order, :category ]).find(params[:id])
    end
  end
end
