require "test_helper"

# El inspector ve la operación e inspecciona. Pagos, comisiones, propuestas y talleres quedan para operador y admin.
class StaffRolesTest < ActionDispatch::IntegrationTest
  setup do
    @inspector = staff_user(role: "inspector")
    @operator = staff_user(role: "operador", email: "ana@kovzu.co")
    @sub_order = sub_order_in_inspection
    @order = @sub_order.order
    @advance = @sub_order.payment(:anticipo)
  end

  test "el inspector ve el pedido e inspecciona, sin botones de pagos ni de decisiones" do
    sign_in_as @inspector

    get operator_root_path
    assert_response :success
    assert_select "a[href=?]", operator_commissions_path, count: 0
    assert_select "a[href=?]", new_operator_requirement_path, count: 0

    get operator_order_path(@order)
    assert_response :success
    assert_select "form[action=?]", void_operator_payment_path(@advance), count: 0
    assert_select "a[href=?]", file_path(@advance.support.attachment), count: 0
    assert_select "form[action=?]", operator_sub_order_inspections_path(@sub_order)

    post operator_sub_order_inspections_path(@sub_order)
    inspection = @sub_order.inspections.sole
    assert_redirected_to operator_inspection_path(inspection)
    items = inspection.items.to_h { |item| [ item.id.to_s, { "result" => "conforme" } ] }
    post close_operator_inspection_path(inspection), params: { items:, result: "aprobado" }
    assert inspection.reload.cerrada?

    get operator_workshop_path(@sub_order.workshop)
    assert_response :success
    assert_select "form[action=?]", pause_operator_workshop_path(@sub_order.workshop), count: 0
  end

  test "el inspector no registra ni anula pagos, no cierra cortes, no verifica talleres ni decide escalamientos" do
    sign_in_as @inspector
    denied = ->(method, path, **params) do
      send(method, path, params:)
      assert_redirected_to operator_root_path, "#{method} #{path}"
      follow_redirect!
      assert_select ".kz-alert", text: /rol de inspector/
    end

    denied.call(:post, void_operator_payment_path(@advance), reason: "Prueba")
    assert @advance.reload.vigente?

    denied.call(:get, new_operator_sub_order_payment_path(@sub_order, tipo: "saldo"))
    denied.call(:post, operator_sub_order_payments_path(@sub_order),
                payment: { kind: "saldo", amount_cop: "500000", paid_on: Date.current, support: fixture_file_upload("soporte.pdf", "application/pdf") })
    assert_nil @sub_order.reload.payment(:saldo)

    denied.call(:get, operator_commissions_path)
    denied.call(:post, operator_commission_cuts_path, month: Date.current.strftime("%Y-%m"))
    assert_equal 0, CommissionCut.count

    workshop = create_workshop("Troqueles Cali", status: "en_verificacion")
    denied.call(:post, approve_pilot_operator_workshop_path(workshop))
    assert workshop.reload.en_verificacion?

    denied.call(:post, operator_sub_order_escalations_path(@sub_order), escalation: { decision: "cancelar", reason: "Prueba" })
    assert_empty @sub_order.escalations

    denied.call(:get, new_operator_order_proposal_path(@order, quote_id: @sub_order.quotes.first.id))
  end

  test "el inspector no abre soportes de pago ni cotizaciones cargadas; sí las fotos de la muestra" do
    sign_in_as @inspector

    get file_path(@advance.support.attachment)
    assert_response :not_found
    get file_path(@sub_order.quotes.first.support.attachment)
    assert_response :not_found
    get file_path(@sub_order.samples.first.photos.attachments.first)
    assert_response :redirect
  end

  test "el operador conserva pagos, comisiones y talleres" do
    sign_in_as @operator

    get operator_order_path(@order)
    assert_select "form[action=?]", void_operator_payment_path(@advance)
    get operator_commissions_path
    assert_response :success
    assert_select "a[href=?]", operator_commissions_path
    get file_path(@advance.support.attachment)
    assert_response :redirect
  end
end
