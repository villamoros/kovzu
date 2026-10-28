require "test_helper"

class CommissionTest < ActiveSupport::TestCase
  setup do
    sub_order = sub_order_in_inspection
    fill_inspection(Inspection.start_for!(sub_order, by: "Pedro")).close!(result: "aprobado", user: staff_user)
    @payment = pay!(sub_order.reload, "saldo")
    @commission = @payment.commission
    @workshop = sub_order.workshop
  end

  test "HU-20: el corte mensual agrupa lo causado por taller" do
    error = assert_raises(CommissionCut::TransitionError) { CommissionCut.run!(month: Date.current.next_month, by: "Ana") }
    assert_match "no ha empezado", error.message

    cut = CommissionCut.run!(month: Date.current, by: "Ana")

    assert_equal [ @commission ], cut.commissions.to_a
    assert_equal [ @workshop ], cut.by_workshop.map(&:first)
    assert_raises(CommissionCut::TransitionError) { CommissionCut.run!(month: Date.current, by: "Ana") }
  end

  test "HU-20: factura y pago por taller, con la cartera por estado" do
    cut = CommissionCut.run!(month: Date.current, by: "Ana")
    assert_equal 100_000, CommissionPortfolio.new.totals[:causada]

    assert_raises(CommissionCut::TransitionError) { cut.invoice!(@workshop, number: "", invoiced_on: nil, due_on: nil, by: "Ana") }
    cut.invoice!(@workshop, number: "FE-12", invoiced_on: Date.current, due_on: Date.current + 5, by: "Ana")
    assert_equal [ "facturada", "FE-12" ], [ @commission.reload.status, @commission.invoice_number ]
    assert_equal 100_000, CommissionPortfolio.new.totals[:facturada]

    cut.mark_paid!(@workshop, paid_on: Date.current, by: "Ana")
    assert @commission.reload.pagada?
    assert_equal 100_000, CommissionPortfolio.new.totals[:pagada]
  end

  test "HU-20 / RN-09: más de 15 días de mora marca al taller, alerta y pausa sus asignaciones" do
    cut = CommissionCut.run!(month: Date.current, by: "Ana")
    cut.invoice!(@workshop, number: "FE-12", invoiced_on: 30.days.ago.to_date, due_on: 15.days.ago.to_date, by: "Ana")
    assert_not @workshop.delinquent?, "15 días todavía no es mora"

    @commission.reload.update!(due_on: 16.days.ago.to_date)

    assert @workshop.delinquent?
    assert_equal :en_mora, @commission.bucket
    assert_equal 100_000, CommissionPortfolio.new.totals[:en_mora]
    assert_includes OperatorDashboard.new.delinquent_workshops, @workshop
    assert_not_includes Workshop.eligible_for_quotes, @workshop

    other = start_order(create_requirement(category: @payment.sub_order.category)).sub_orders.first
    ready_sheet!(other)
    assert_raises(SubOrder::TransitionError) { other.request_quotes!([ @workshop.id ], by: "Ana") }
  end
end
