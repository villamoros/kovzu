module Operator
  # HU-09: el operador registra la muestra con fotos para que el cliente la revise.
  class SamplesController < BaseController
    before_action :set_sub_order

    def new
      @sample = Sample.new(sub_order: @sub_order, kind: "fisica")
    end

    def create
      attrs = params.expect(sample: [ :kind, :notes, { photos: [] } ])
      @sub_order.register_sample!(kind: attrs[:kind], notes: attrs[:notes], photos: Array(attrs[:photos]).compact_blank, by: actor_name)
      redirect_to operator_order_path(@sub_order.order), notice: "Muestra registrada. Le avisamos al cliente para que la revise."
    rescue SubOrder::TransitionError, ActiveRecord::RecordInvalid => error
      @sample = Sample.new(sub_order: @sub_order, kind: attrs[:kind], notes: attrs[:notes])
      flash.now[:alert] = error.is_a?(ActiveRecord::RecordInvalid) ? error.record.errors.full_messages.to_sentence : error.message
      render :new, status: :unprocessable_entity
    end

    private

    def set_sub_order
      @sub_order = SubOrder.includes(:order, :category, :workshop).find(params[:sub_order_id])
    end
  end
end
