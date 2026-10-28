module Operator
  # RF-08: arma la propuesta con la cotización elegida y la envía al cliente.
  class ProposalsController < BaseController
    before_action :set_order_and_quote

    def new
      @proposal = Proposal.new(order: @order, quote: @quote, management_fee_cop: @order.management_fee_cop, advance_percent: 50)
    end

    def create
      attrs = params.expect(proposal: %i[management_fee_cop advance_percent terms])
      Proposal.send_for!(@quote, management_fee_cop: attrs[:management_fee_cop], advance_percent: attrs[:advance_percent],
                                 terms: attrs[:terms], by: actor_name)
      redirect_to operator_order_path(@order), notice: "Propuesta enviada a #{@order.client_company.name}."
    rescue Proposal::TransitionError, ActiveRecord::RecordInvalid => error
      @proposal = Proposal.new(order: @order, quote: @quote, **attrs.to_h.symbolize_keys)
      flash.now[:alert] = error.message
      render :new, status: :unprocessable_entity
    end

    private

    def set_order_and_quote
      @order = Order.includes(:client_company).find_by!(code: params[:order_id])
      @quote = Quote.joins(:sub_order).where(sub_orders: { order_id: @order.id }).find(params[:quote_id] || params.dig(:proposal, :quote_id))
    end
  end
end
