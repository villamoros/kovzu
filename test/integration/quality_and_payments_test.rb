require "test_helper"

# Paso 4: el taller cotiza por enlace, inspección desde el celular, acta, pagos y comisiones.
class QualityAndPaymentsTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @operator = User.create!(clerk_id: "user_operador", email: "ana@kovzu.co", first_name: "Ana", role: "operador")
  end

  test "HU-05: el taller cotiza desde el enlace sin cuenta y sin ver datos del cliente" do
    sub_order = start_order.sub_orders.first
    ready_sheet!(sub_order)
    quote = sub_order.request_quotes!([ create_workshop("Cartón Valle", category: sub_order.category).id ], by: "Ana").first

    get workshop_quote_path(quote.token)
    assert_response :success
    assert_select "h1", text: "Caja plegadiza"
    assert_select "p", text: "Sin rayones"
    assert_no_match "Aromas del Valle", response.body
    assert_select "a[href=?]", sign_in_path, count: 0

    patch workshop_quote_path(quote.token), params: { quote: { price_cop: "950000", lead_days: "8", valid_until: Date.current + 5 } }
    assert_redirected_to workshop_quote_path(quote.token)
    assert quote.reload.solicitada?, "sin aceptar la ficha no se envía"

    patch workshop_quote_path(quote.token), params: { quote: { price_cop: "950000", lead_days: "8", valid_until: Date.current + 5 }, accept_sheet: "1" }
    assert_redirected_to workshop_quote_path(quote.token)
    follow_redirect!
    assert_select "h2", text: "Cotización enviada"
    assert_select "form[action=?]", workshop_quote_path(quote.token), count: 0
    assert quote.reload.recibida?

    get workshop_quote_path("token-que-no-existe")
    assert_response :not_found
  end

  test "HU-05: el enlace vencido pide uno nuevo y el operador lo renueva" do
    sub_order = start_order.sub_orders.first
    ready_sheet!(sub_order)
    quote = sub_order.request_quotes!([ create_workshop("Cartón Valle", category: sub_order.category).id ], by: "Ana").first
    quote.update!(link_expires_at: 1.minute.ago)

    get workshop_quote_path(quote.token)
    assert_select ".kz-alert__title", text: "Este enlace venció"
    post renewal_workshop_quote_path(quote.token)
    assert quote.reload.renewal_requested_at

    sign_in_as @operator
    get operator_order_path(sub_order.order)
    assert_select "span", text: "El taller pidió un enlace nuevo"
    post renew_operator_quote_path(quote)
    assert_redirected_to operator_order_path(sub_order.order)
    assert quote.reload.link_usable?
  end

  test "HU-12 / HU-13 / HU-19 / HU-20: de producción terminada a la comisión cobrada" do
    sub_order = confirmed_sub_order
    order = sub_order.order
    pay!(sub_order, "anticipo")
    sub_order.reload.register_sample!(kind: "fisica", notes: nil, photos: [ fixture_upload("muestra.png", "image/png") ], by: "Ana")
                    .approve!(user: client_user(order.client_company))
    inspector = staff_user

    sign_in_as inspector
    get operator_order_path(order)
    assert_select "button", text: "Producción terminada"
    post finish_production_operator_sub_order_path(sub_order)
    assert sub_order.reload.inspeccion?

    post operator_sub_order_inspections_path(sub_order)
    inspection = sub_order.inspections.sole
    assert_redirected_to operator_inspection_path(inspection)
    follow_redirect!
    assert_select ".kz-display", text: "50"
    assert_select "input[type=file][capture=environment]", inspection.items.size

    medidas, *rest = inspection.items.to_a
    items = { medidas.id.to_s => { result: "no_conforme", severity: "menor", measurement: "121 mm", note: "1 mm por encima" } }
    rest.each { |item| items[item.id.to_s] = { result: "conforme" } }
    post close_operator_inspection_path(inspection), params: { items:, result: "aprobado_con_desviacion" }
    assert_response :unprocessable_entity
    assert_select ".kz-alert", text: /adjunta al menos una foto/
    assert_equal "121 mm", medidas.reload.measurement, "el avance se guarda aunque no se pueda cerrar"

    post close_operator_inspection_path(inspection),
         params: { items:, photos: { medidas.id.to_s => [ fixture_file_upload("muestra.png", "image/png") ] }, result: "aprobado_con_desviacion" }
    assert_redirected_to operator_inspection_path(inspection)
    assert inspection.reload.cerrada?
    perform_enqueued_jobs(only: InspectionReportJob)
    assert inspection.reload.report.attached?

    sign_in_as client_user(order.client_company)
    get order_path(order)
    assert_select "a[href=?]", order_inspection_path(order, inspection), text: "Revisar el acta"
    get order_inspection_path(order, inspection)
    assert_select "h2", text: "¿Aceptas la desviación?"
    assert_select "a", text: "Descargar acta PDF"
    post accept_deviation_order_inspection_path(order, inspection)
    assert_redirected_to order_path(order)
    follow_redirect!
    assert_select "h3", text: /ya puedes pagar el saldo/

    sign_in_as @operator
    get new_operator_sub_order_payment_path(sub_order, tipo: "saldo")
    assert_select "input[name='payment[amount_cop]'][value='500000']"
    post operator_sub_order_payments_path(sub_order), params: { payment: { kind: "saldo", amount_cop: "480000", paid_on: Date.current,
                                                                            support: fixture_file_upload("soporte.pdf", "application/pdf") } }
    assert_response :unprocessable_entity
    assert_select ".kz-alert__title", text: "El valor no coincide con lo pactado"
    post operator_sub_order_payments_path(sub_order), params: { payment: { kind: "saldo", amount_cop: "500000", paid_on: Date.current,
                                                                            support: fixture_file_upload("soporte.pdf", "application/pdf") } }
    assert_redirected_to operator_order_path(order)
    assert_equal 100_000, sub_order.commissions.sole.amount_cop

    get operator_commissions_path
    assert_select "a", text: "Cartón Valle"
    post operator_commission_cuts_path, params: { month: Date.current.strftime("%Y-%m") }
    cut = CommissionCut.sole
    assert_redirected_to operator_commission_cut_path(cut)
    get operator_commission_cut_path(cut, format: :csv)
    assert_match "Cartón Valle", response.body
    workshop = sub_order.workshop
    post invoice_operator_commission_cut_path(cut), params: { workshop_id: workshop.id, invoice_number: "FE-7", invoiced_on: Date.current, due_on: Date.current }
    post pay_operator_commission_cut_path(cut), params: { workshop_id: workshop.id, paid_on: Date.current }
    assert sub_order.commissions.sole.pagada?

    post deliver_operator_sub_order_path(sub_order)
    assert order.reload.entregado?
  end

  test "un cliente no ve el acta de otra empresa" do
    sub_order = sub_order_in_inspection
    inspection = fill_inspection(Inspection.start_for!(sub_order, by: "Pedro"))
    inspection.close!(result: "aprobado", user: staff_user)

    sign_in_as client_user(ClientCompany.create!(name: "Otra"), email: "otra@otra.co")
    get order_inspection_path(sub_order.order, inspection)
    assert_response :not_found
  end
end
