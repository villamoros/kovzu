module Operator
  # HU-19: anticipo y saldo con soporte. Si el valor no coincide con lo pactado, se confirma antes de guardar.
  class PaymentsController < BaseController
    before_action :set_sub_order, only: %i[new create]

    def new
      kind = Payment::KINDS.key?(params[:tipo]) ? params[:tipo] : "anticipo"
      @payment = Payment.new(sub_order: @sub_order, kind:, amount_cop: @sub_order.expected_payment_cop(kind), paid_on: Date.current)
    end

    def create
      attrs = params.expect(payment: %i[kind amount_cop paid_on notes support])
      payment = @sub_order.register_payment!(kind: attrs[:kind], amount_cop: attrs[:amount_cop], paid_on: attrs[:paid_on], support: attrs[:support],
                                             notes: attrs[:notes], confirm_mismatch: params[:confirm_mismatch], by: actor_name)
      notice = payment.anticipo? ? "Anticipo registrado. El subpedido pasa a la etapa de muestra." : "Saldo registrado. Se causó la comisión de #{@sub_order.workshop.name}."
      redirect_to operator_order_path(@sub_order.order), notice:
    rescue SubOrder::TransitionError, Payment::TransitionError, ActiveRecord::RecordInvalid => error
      @payment = Payment.new(sub_order: @sub_order, kind: attrs[:kind], amount_cop: attrs[:amount_cop], paid_on: attrs[:paid_on], notes: attrs[:notes])
      @mismatch = error.is_a?(Payment::AmountMismatch)
      flash.now[:alert] = error.is_a?(ActiveRecord::RecordInvalid) ? error.record.errors.full_messages.to_sentence : error.message
      render :new, status: :unprocessable_entity
    end

    def void
      payment = Payment.includes(sub_order: :order).find(params[:id])
      payment.void!(params[:reason], by: actor_name)
      redirect_to operator_order_path(payment.order), notice: "#{payment.kind_label} anulado. El soporte queda en el historial."
    end

    private

    def set_sub_order
      @sub_order = SubOrder.includes(:order, :workshop, :category).find(params[:sub_order_id])
    end
  end
end
