require "test_helper"

# Recorre el portal del cliente y la parte del operador que lo alimenta (paso 3).
class ClientPortalTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  setup do
    @category = create_category
    @operator = User.create!(clerk_id: "user_operador", email: "ana@kovzu.co", first_name: "Ana", role: "operador")
  end

  test "un cliente nuevo registra su empresa con la autorización de datos" do
    user = User.create!(clerk_id: "user_nuevo", email: "laura@aromas.co", first_name: "Laura")
    sign_in_as user

    get dashboard_path
    assert_redirected_to new_company_path

    post company_path, params: { client_company: { name: "Aromas del Valle" } }
    assert_response :unprocessable_entity
    assert_select ".kz-alert", text: /autorización/

    post company_path, params: { client_company: { name: "Aromas del Valle", segment: "marca" }, data_consent: "1" }
    assert_redirected_to new_requirement_path
    assert_equal "Aromas del Valle", user.reload.client_company.name
    assert user.data_consent_at
  end

  test "el equipo de KOVZU va a su panel" do
    sign_in_as @operator

    get dashboard_path
    assert_redirected_to operator_root_path
  end

  test "HU-01 y HU-02: enviar un requerimiento guiado con archivos y responder la aclaración" do
    company = ClientCompany.create!(name: "Aromas del Valle")
    sign_in_as client_user(company)

    get new_requirement_path
    assert_select "a[href=?]", new_requirement_path(categoria: @category.slug)
    get new_requirement_path(categoria: @category.slug)
    assert_select "input[name='requirement[material]'][required]"

    post requirements_path, params: { requirement: { category_id: @category.id, title: "Caja", quantity: 500 } }
    assert_response :unprocessable_entity
    assert_select ".kz-field--error #requirement_field_material"

    assert_enqueued_emails(1) do
      post requirements_path, params: { requirement: { category_id: @category.id, title: "Caja", quantity: 500, material: "C14",
                                                       files: [ fixture_file_upload("plano.dxf", "application/dxf") ] } }
    end
    requirement = company.requirements.last
    assert_redirected_to requirement_path(requirement)
    assert requirement.files.attached?

    requirement.ask_clarification!("¿Qué tamaño de frasco?", by: "Ana")
    get dashboard_path
    assert_select "a[href=?]", requirement_path(requirement), text: /Responder/

    post answer_requirement_path(requirement), params: { answer: "Frasco de 30 ml" }
    assert requirement.reload.en_revision?
    assert_equal "cliente", requirement.messages.last.author_role
  end

  test "un cliente no ve lo de otra empresa" do
    other = create_requirement
    sign_in_as client_user(ClientCompany.create!(name: "Otra"))

    get requirement_path(other)
    assert_response :not_found
  end

  test "del operador al cliente: cotización, propuesta, aceptación y muestra" do
    sub_order = start_order.sub_orders.first
    ready_sheet!(sub_order)
    workshop = create_workshop("Cartón Valle", category: sub_order.category)
    quote = sub_order.request_quotes!([ workshop.id ], by: "Ana").first
    order = sub_order.order

    sign_in_as @operator
    get edit_operator_quote_path(quote)
    assert_response :success
    patch operator_quote_path(quote), params: { quote: { price_cop: 900_000, lead_days: 12, support: fixture_file_upload("soporte.pdf", "application/pdf") } }
    assert_redirected_to operator_order_path(order)
    get operator_order_path(order)
    assert_select "a[href=?]", new_operator_order_proposal_path(order, quote_id: quote.id)

    get new_operator_order_proposal_path(order, quote_id: quote.id)
    assert_response :success
    post operator_order_proposals_path(order), params: { proposal: { quote_id: quote.id, management_fee_cop: 150_000, advance_percent: 50 } }
    assert_redirected_to operator_order_path(order)

    sign_in_as client_user(order.client_company)
    get dashboard_path
    assert_select "a[href=?]", order_proposal_path(order)
    get order_proposal_path(order)
    assert_select "dd", text: "$ 1.050.000"
    post accept_order_proposal_path(order)
    assert_redirected_to order_path(order)
    assert order.reload.confirmado?

    get order_path(order)
    assert_select ".kz-timeline__item", 5

    sign_in_as @operator
    get operator_order_path(order)
    assert_select "a[href=?]", new_operator_sub_order_payment_path(sub_order, tipo: "anticipo")
    post operator_sub_order_payments_path(sub_order), params: { payment: { kind: "anticipo", amount_cop: "450.000", paid_on: Date.current,
                                                                            support: fixture_file_upload("soporte.pdf", "application/pdf") } }
    assert_redirected_to operator_order_path(order)
    assert sub_order.reload.muestra_pendiente?
    post operator_sub_order_samples_path(sub_order), params: { sample: { kind: "fisica", photos: [ fixture_file_upload("muestra.png", "image/png") ] } }
    assert_redirected_to operator_order_path(order)
    sample = sub_order.samples.sole

    sign_in_as order.client_company.users.first
    get order_path(order)
    assert_select "form[action=?]", approve_sample_path(sample)
    post reject_sample_path(sample), params: { comment: "Logo descentrado" }
    assert sample.reload.rechazada?
    get order_path(order)
    assert_select ".kz-timeline__meta", text: /Logo descentrado/
  end
end
