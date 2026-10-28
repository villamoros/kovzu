require "test_helper"

class ProposalTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  setup do
    @sub_order = quoted_sub_order(price: 1_000_000, lead_days: 12)
    @order = @sub_order.order
    @client = client_user(@order.client_company)
  end

  test "enviar la propuesta elige la cotización, avisa al cliente y deja el pedido en propuesta enviada" do
    proposal = nil
    assert_enqueued_emails(1) { proposal = send_proposal(@sub_order) }

    assert proposal.enviada?
    assert @sub_order.quotes.first.reload.elegida?
    assert @order.reload.propuesta_enviada?
    assert_equal 1_150_000, proposal.total_cop
    assert_equal 500_000, proposal.advance_cop
    assert_equal 500_000, proposal.balance_cop
    assert_equal BusinessDays.add(Date.current, 12), proposal.promised_on
  end

  test "una ficha que no está lista no entra en una propuesta" do
    @sub_order.current_tech_sheet.revise!({ acceptance_criteria: "Otro criterio" }, by: "Ana")

    assert_raises(Proposal::TransitionError) { send_proposal(@sub_order) }
  end

  test "HU-07: aceptar registra la aprobación, confirma el pedido, causa el fee y arma los hitos" do
    proposal = send_proposal(@sub_order)

    proposal.accept!(user: @client)

    approval = proposal.approvals.sole
    assert_equal [ "aceptada", "cliente", @client, proposal.tech_sheet.version ], [ approval.decision, approval.actor_role, approval.user, approval.version ]
    assert proposal.reload.aceptada?
    assert proposal.tech_sheet.reload.aceptada?
    assert @order.reload.confirmado?
    assert_equal 150_000, @order.management_fee_cop
    assert @order.fee_accrued_at
    @sub_order.reload
    assert @sub_order.anticipo_pendiente?
    assert_equal @sub_order.quotes.first.workshop, @sub_order.workshop
    assert_equal 5, @sub_order.milestones.count
    assert_equal BusinessDays.add(Date.current, 12), @order.promised_on
  end

  test "HU-07: pedir cambios devuelve la propuesta al operador sin causar el fee" do
    proposal = send_proposal(@sub_order)

    assert_raises(Proposal::TransitionError) { proposal.request_changes!(" ", user: @client) }
    proposal.request_changes!("¿Se puede en 10 días?", user: @client)

    assert proposal.cambios_solicitados?
    assert @order.reload.cotizando?
    assert_nil @order.fee_accrued_at
    assert_equal "cambios_solicitados", proposal.approvals.sole.decision
    assert_includes OperatorDashboard.new.attention.map(&:reason), "El cliente pidió cambios a la propuesta"

    second = send_proposal(@sub_order, fee: 120_000)
    assert proposal.reload.reemplazada?
    assert_equal second, @order.reload.current_proposal
  end

  test "HU-07: con la cotización vencida no se puede aceptar y el operador ve la alerta" do
    proposal = send_proposal(@sub_order)
    proposal.quote.update_columns(valid_until: Date.yesterday)

    error = assert_raises(Proposal::TransitionError) { proposal.accept!(user: @client) }
    assert_match "venció", error.message
    assert proposal.reload.enviada?
    assert_includes OperatorDashboard.new.attention.map(&:reason), "Venció la cotización de la propuesta"
  end
end
