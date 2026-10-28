require "test_helper"

class EscalationTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @sub_order = escalated_sub_order
    @order = @sub_order.order
    @failed = @sub_order.workshop
    @client = client_user(@order.client_company)
  end

  test "RN-06: cada decisión exige motivo y el subpedido escalado" do
    error = assert_raises(ActiveRecord::RecordInvalid) { decide("reasignar", reason: "") }
    assert_match "Motivo", error.message
    assert_raises(ActiveRecord::RecordInvalid) { decide("otra") }
    assert_raises(ActiveRecord::RecordInvalid) { decide("descuento", discount_cop: nil) }
    assert_raises(Escalation::TransitionError) { decide("descuento", discount_cop: @sub_order.expected_payment_cop(:saldo)) }
    assert @sub_order.reload.escalado?
    assert_empty @sub_order.escalations

    @sub_order.update!(status: "reproceso")
    assert_raises(Escalation::TransitionError) { decide("cancelar") }
  end

  test "RN-06 / RN-05: reasignar saca al taller, deja el anticipo por devolver y reinicia el conteo de rechazos" do
    advance = @sub_order.payment(:anticipo)
    escalation = decide("reasignar")

    @sub_order.reload
    assert @sub_order.cotizando?
    assert_nil @sub_order.workshop
    assert @sub_order.reassigned_at
    assert @order.reload.cotizando?
    assert advance.reload.anulado?
    assert_match "#{@failed.name} debe devolver el anticipo", advance.void_reason
    assert escalation.refund_pending?
    assert_equal advance.amount_cop, escalation.refund_cop
    assert_includes Escalation.refund_pending, escalation
    assert @sub_order.quotes.find_by(workshop: @failed).no_elegida?
    assert_equal "pedido.escalado_reasignar", @order.audit_events.first.action

    # El taller que falló no puede volver a cotizar; otro sí.
    assert_raises(ActiveRecord::RecordInvalid) { @sub_order.request_quotes!([ @failed.id ], by: "Ana") }
    other = create_workshop("Empaques del Sur", category: @sub_order.category)
    quote = @sub_order.request_quotes!([ other.id ], by: "Ana").first
    quote.record_by_operator!({ price_cop: 1_100_000, lead_days: 12, valid_until: 10.days.from_now.to_date },
                              support: fixture_upload("soporte.pdf", "application/pdf"), by: "Ana")

    fee_accrued_at = @order.reload.fee_accrued_at
    proposal = Proposal.send_for!(quote, management_fee_cop: 999_999, advance_percent: 50, terms: nil, by: "Ana")
    assert proposal.fee_paid_before?
    assert_equal 150_000, proposal.management_fee_cop
    assert_equal 1_100_000, proposal.total_cop
    proposal.accept!(user: @client)

    @sub_order.reload
    assert @sub_order.anticipo_pendiente?
    assert_equal other, @sub_order.workshop
    assert_equal proposal, @sub_order.accepted_proposal
    assert_equal 550_000, @sub_order.expected_payment_cop(:anticipo)
    assert_equal fee_accrued_at.to_i, @order.reload.fee_accrued_at.to_i
    assert_equal 5, @sub_order.milestones.count

    # El nuevo taller empieza de cero: un primer rechazo es reproceso, no escalamiento.
    produce!(@sub_order)
    inspection = reject!(@sub_order)
    assert_nil inspection.reinspection_of
    assert @sub_order.reload.reproceso?

    escalation.register_refund!(received_on: Date.current, by: "Ana")
    assert_not escalation.reload.refund_pending?
    assert_raises(Escalation::TransitionError) { escalation.register_refund!(received_on: Date.current, by: "Ana") }
  end

  test "RN-06: el descuento espera al cliente; si lo acepta, baja el saldo y la comisión" do
    balance = @sub_order.expected_payment_cop(:saldo)
    escalation = decide("descuento", discount_cop: "100.000")
    assert escalation.esperando_cliente?
    assert_equal 100_000, escalation.discount_cop
    assert_nil escalation.refund_cop
    assert @sub_order.reload.escalado?
    assert_equal @sub_order.pending_discount, escalation
    assert_raises(Escalation::TransitionError) { decide("cancelar") }
    assert_includes OperatorDashboard.new.attention.map(&:reason), "Descuento esperando la respuesta del cliente"

    escalation.accept_discount!(user: @client)

    assert escalation.reload.aplicada?
    assert_equal "aceptada", escalation.approvals.last.decision
    @sub_order.reload
    assert @sub_order.aprobado?
    assert @order.reload.en_curso?
    assert_equal balance - 100_000, @sub_order.expected_payment_cop(:saldo)
    assert @sub_order.balance_enabled?

    pay!(@sub_order, "saldo")
    commission = @sub_order.commissions.last
    assert_equal 900_000, commission.base_cop
    assert_equal 90_000, commission.amount_cop
  end

  test "RN-06: si el cliente rechaza el descuento, el operador elige otra salida" do
    escalation = decide("descuento", discount_cop: 100_000)
    assert_raises(Escalation::TransitionError) { escalation.reject_discount!("", user: @client) }
    escalation.reject_discount!("Prefiero otro taller", user: @client)

    assert escalation.reload.rechazada?
    assert @sub_order.reload.escalado?
    assert_nil @sub_order.pending_discount
    assert_equal 0, @sub_order.discount_cop
    assert_raises(Escalation::TransitionError) { escalation.accept_discount!(user: @client) }

    decide("reasignar")
    assert @sub_order.reload.cotizando?
  end

  test "RN-06 / RN-07: cancelar cierra el subpedido y el pedido; el fee se devuelve solo si se marca" do
    escalation = decide("cancelar", fee_refunded: "1")

    assert @sub_order.reload.cancelado?
    assert @order.reload.cancelado?
    assert escalation.fee_refunded?
    assert escalation.refund_pending?
    assert @sub_order.payments.all?(&:anulado?)
    assert_includes OperatorDashboard.new.refunds_pending, escalation
  end

  test "RN-06: el descuento no admite devolver el fee ni otros campos de otra decisión" do
    escalation = decide("reasignar", discount_cop: 50_000, fee_refunded: "1")
    assert_nil escalation.discount_cop
    assert_not escalation.fee_refunded?
  end

  private

  def decide(decision, reason: "El taller no corrigió las medidas", discount_cop: nil, fee_refunded: false)
    Escalation.decide!(@sub_order.reload, decision:, reason:, discount_cop:, fee_refunded:, by: "Ana")
  end

  def escalated_sub_order
    sub_order = sub_order_in_inspection
    reject!(sub_order)
    sub_order.reload.finish_production!(by: "Ana")
    reject!(sub_order)
    sub_order.reload
  end

  def produce!(sub_order)
    pay!(sub_order, "anticipo")
    sample = sub_order.reload.register_sample!(kind: "fisica", notes: nil, photos: [ fixture_upload("muestra.png", "image/png") ], by: "Ana")
    sample.approve!(user: @client)
    sub_order.reload.finish_production!(by: "Ana")
  end

  def reject!(sub_order)
    inspection = fill_inspection(Inspection.start_for!(sub_order.reload, by: "Pedro"), nonconforming: { "medidas" => "mayor" })
    inspection.close!(result: "rechazado", rework_due_on: BusinessDays.add(Date.current, 5), user: staff_user)
    inspection
  end
end
