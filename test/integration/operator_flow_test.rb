require "test_helper"

# Recorre el panel del operador con una sesión de Clerk simulada.
class OperatorFlowTest < ActionDispatch::IntegrationTest
  FakeClerk = Struct.new(:user_id) do
    def user? = true
  end

  module FakeClerkSession
    private

    def clerk
      (user_id = Thread.current[:kovzu_test_clerk_user_id]) ? FakeClerk.new(user_id) : super
    end
  end

  ApplicationController.prepend(FakeClerkSession)

  setup do
    @category = create_category
    @operator = User.create!(clerk_id: "user_operador", email: "ana@kovzu.co", first_name: "Ana", role: "operador")
    sign_in_as @operator
  end

  teardown { Thread.current[:kovzu_test_clerk_user_id] = nil }

  test "un cliente no entra al panel" do
    sign_in_as User.create!(clerk_id: "user_cliente", email: "laura@aromas.co", role: "cliente")

    get operator_root_path
    assert_redirected_to dashboard_path
  end

  test "del requerimiento a las solicitudes de cotización" do
    workshops = 2.times.map { |index| create_workshop("Taller #{index + 1}", category: @category) }

    get operator_root_path
    assert_response :success

    post operator_requirements_path, params: { requirement: { client_company_name: "Aromas del Valle", title: "Caja plegadiza",
                                                                category_id: @category.id, quantity: 500, channel: "whatsapp" } }
    requirement = Requirement.last
    assert_redirected_to operator_requirement_path(requirement)
    get operator_requirements_path
    assert_select "td", text: "Aromas del Valle"

    post complete_operator_requirement_path(requirement), params: { category_id: @category.id }
    post start_order_operator_requirement_path(requirement)
    order = requirement.reload.order
    sheet = order.sub_orders.first.current_tech_sheet
    get operator_order_path(order)
    assert_response :success

    get edit_operator_tech_sheet_path(sheet)
    assert_response :success
    patch operator_tech_sheet_path(sheet), params: { tech_sheet: { acceptance_criteria: "Sin rayones",
                                                                  fields: sheet.fields.merge("material" => "Plegadiza C14") } }
    post ready_operator_tech_sheet_path(sheet)
    assert_redirected_to new_operator_sub_order_quote_request_path(sheet.sub_order)

    follow_redirect!
    assert_select "input[name='workshop_ids[]']", 2

    post operator_sub_order_quote_request_path(sheet.sub_order), params: { workshop_ids: workshops.map(&:id) }
    assert_redirected_to operator_order_path(order)
    assert_equal 2, sheet.sub_order.quotes.count
    assert order.reload.cotizando?

    get operator_order_path(order)
    assert_select "li", text: /Cotizaciones solicitadas/
  end

  test "una regla rota vuelve con el aviso" do
    requirement = create_requirement(category: nil)

    post complete_operator_requirement_path(requirement)
    assert_redirected_to operator_root_path
    assert_match "categoría", flash[:alert]
  end

  test "registrar y verificar un taller" do
    get new_operator_workshop_path
    assert_response :success

    post operator_workshops_path, params: { workshop: {
      name: "Cartones del Sur", has_rut: "1", e_invoicing: "1",
      visit_checklist: { maquinas: "1", fotos: "1", visita: "1" },
      capabilities_attributes: { "0" => { category_id: @category.id, min_volume: 100, max_volume: 5000 } }
    } }
    workshop = Workshop.last
    assert_redirected_to operator_workshop_path(workshop)
    assert workshop.prospecto?
    assert_equal 1, workshop.capabilities.count

    post start_verification_operator_workshop_path(workshop)
    post approve_pilot_operator_workshop_path(workshop)
    assert workshop.reload.verificado?

    get operator_workshops_path(status: "verificado", category_id: @category.id)
    assert_select "a", text: "Cartones del Sur"
    get operator_workshop_path(workshop)
    assert_select "li", text: /Taller verificado/
    get edit_operator_workshop_path(workshop)
    assert_response :success
  end

  test "un taller sin nombre no se guarda y muestra el error en español" do
    post operator_workshops_path, params: { workshop: { name: "" } }

    assert_response :unprocessable_entity
    assert_select ".kz-alert", text: /Nombre no puede estar en blanco/
  end

  private

  def sign_in_as(user)
    Thread.current[:kovzu_test_clerk_user_id] = user.clerk_id
  end
end
