require "test_helper"

class PaymentTest < ActiveSupport::TestCase
  setup do
    @sub_order = confirmed_sub_order
  end

  test "HU-19: el anticipo con su soporte pasa el subpedido a la etapa de muestra" do
    payment = pay!(@sub_order, "anticipo")

    assert_equal 500_000, payment.amount_cop
    assert @sub_order.reload.muestra_pendiente?
    assert @sub_order.milestones.find_by(kind: "anticipo").done?
    assert_raises(SubOrder::TransitionError) { pay!(@sub_order, "anticipo") }
  end

  test "dos pestañas que registran el anticipo a la vez guardan un solo pago" do
    tab_a = SubOrder.find(@sub_order.id)
    tab_b = SubOrder.find(@sub_order.id)
    tab_b.payments.load

    pay!(tab_a, "anticipo")
    error = assert_raises(SubOrder::TransitionError) { pay!(tab_b, "anticipo") }
    assert_match "Ya hay un anticipo registrado", error.message
    assert_equal 1, @sub_order.payments.count
  end

  test "la base de datos rechaza un segundo pago vigente del mismo tipo y una segunda comisión activa" do
    payment = pay!(@sub_order, "anticipo")
    copy = payment.dup
    copy.support.attach(fixture_upload("soporte.pdf", "application/pdf"))
    assert_raises(ActiveRecord::RecordNotUnique) { copy.save!(validate: false) }

    payment.void!("Transferencia devuelta", by: "Ana")
    assert pay!(@sub_order.reload, "anticipo").vigente?, "anulado el anterior, se puede registrar otro"

    sub_order = approved_sub_order
    commission = pay!(sub_order, "saldo").commission
    assert_raises(ActiveRecord::RecordNotUnique) { commission.dup.save!(validate: false) }
  end

  test "HU-19: un valor distinto del pactado advierte y pide confirmar" do
    error = assert_raises(Payment::AmountMismatch) { pay!(@sub_order, "anticipo", amount: 450_000) }
    assert_match "$ 500.000", error.message
    assert @sub_order.reload.anticipo_pendiente?
    assert_empty @sub_order.payments

    payment = pay!(@sub_order, "anticipo", amount: "450.000", confirm_mismatch: "1")
    assert_equal(-50_000, payment.difference_cop)
  end

  test "HU-19: el soporte es obligatorio y el pago no se borra, solo se anula con motivo" do
    assert_raises(ActiveRecord::RecordInvalid) do
      @sub_order.register_payment!(kind: "anticipo", amount_cop: 500_000, paid_on: Date.current, support: nil, by: "Ana")
    end
    payment = pay!(@sub_order, "anticipo")

    assert_not payment.destroy
    assert Payment.exists?(payment.id)
    assert_raises(Payment::TransitionError) { payment.void!("", by: "Ana") }
    payment.void!("El soporte era de otro pedido", by: "Ana")

    assert payment.anulado?
    assert payment.support.attached?
    assert @sub_order.reload.anticipo_pendiente?, "vuelve a esperar el anticipo si aún no hay muestra"
  end

  test "RF-29: el saldo solo se habilita con el acta aprobada" do
    pay!(@sub_order, "anticipo")
    assert_raises(SubOrder::TransitionError) { pay!(@sub_order, "saldo") }
  end

  test "HU-19 / RN-08: el saldo con acta aprobada causa la comisión del taller sobre el valor antes de IVA" do
    sub_order = approved_sub_order
    sub_order.workshop.update!(commission_percent: 12)

    payment = pay!(sub_order, "saldo")
    commission = payment.commission

    assert_equal [ 1_000_000, 12, 120_000 ], [ commission.base_cop, commission.percent, commission.amount_cop ]
    assert commission.causada?
    assert_equal sub_order.workshop, commission.workshop
    assert sub_order.balance_paid?
  end

  test "anular el saldo anula la comisión mientras no esté facturada" do
    sub_order = approved_sub_order
    payment = pay!(sub_order, "saldo")
    payment.void!("Transferencia devuelta", by: "Ana")

    assert payment.reload.commission.nil?
    assert_equal "anulada", Commission.find_by(payment:).status
    assert sub_order.reload.balance_enabled?
  end

  test "con el saldo pagado se registra la entrega y se cierra el pedido" do
    sub_order = approved_sub_order
    assert_raises(SubOrder::TransitionError) { sub_order.deliver!(by: "Ana") }

    pay!(sub_order, "saldo")
    sub_order.reload.deliver!(by: "Ana")

    assert sub_order.entregado?
    assert sub_order.order.reload.entregado?
    assert sub_order.order.delivered_at
  end

  private

  def approved_sub_order
    sub_order = sub_order_in_inspection
    inspection = fill_inspection(Inspection.start_for!(sub_order, by: "Pedro"))
    inspection.close!(result: "aprobado", user: staff_user)
    sub_order.reload
  end
end
