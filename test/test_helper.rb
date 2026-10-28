ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Datos mínimos para las pruebas del modelo de KOVZU.
    def create_category(slug: "empaques", fields: nil)
      fields ||= [
        { "key" => "producto", "label" => "Producto", "required" => true },
        { "key" => "cantidad", "label" => "Cantidad", "required" => true },
        { "key" => "material", "label" => "Material", "required" => true },
        { "key" => "acabado", "label" => "Acabado" }
      ]
      checks = [ { "key" => "medidas", "label" => "Medidas internas", "tolerance" => "± 1 mm" }, { "key" => "cantidad", "label" => "Cantidad completa" } ]
      Category.find_by(slug:) || Category.create!(slug:, name: slug.capitalize, min_lead_days: 5, tech_sheet_template: fields, inspection_template: checks)
    end

    def create_workshop(name, category: nil, status: "verificado", level: nil, score: nil, min_volume: nil, max_volume: nil)
      verified = status.in?(%w[verificado pausado])
      workshop = Workshop.create!(name:, status:, level:, score:, has_rut: verified, e_invoicing: verified)
      workshop.capabilities.create!(category:, min_volume:, max_volume:) if category
      workshop
    end

    def create_requirement(category: create_category, **attrs)
      company = ClientCompany.create!(name: "Aromas del Valle")
      Requirement.create!({ client_company: company, category:, title: "Caja plegadiza", quantity: 500, material: "Plegadiza C14" }.merge(attrs))
    end

    def start_order(requirement = create_requirement)
      requirement.mark_complete!(by: "Ana")
      Order.start_from!(requirement, by: "Ana")
    end

    def ready_sheet!(sub_order)
      sheet = sub_order.current_tech_sheet
      sheet.update!(acceptance_criteria: "Sin rayones")
      sheet.mark_ready!(by: "Ana")
      sheet
    end

    def fixture_upload(name, type)
      { io: file_fixture(name).open, filename: name, content_type: type }
    end

    # Pedido con una cotización recibida, listo para proponer.
    def quoted_sub_order(price: 1_000_000, lead_days: 12, valid_until: 10.days.from_now.to_date)
      sub_order = start_order.sub_orders.first
      ready_sheet!(sub_order)
      workshop = create_workshop("Cartón Valle", category: sub_order.category)
      quote = sub_order.request_quotes!([ workshop.id ], by: "Ana").first
      quote.record_by_operator!({ price_cop: price, lead_days:, valid_until: }, support: fixture_upload("soporte.pdf", "application/pdf"), by: "Ana")
      sub_order.reload
    end

    def send_proposal(sub_order, fee: 150_000)
      Proposal.send_for!(sub_order.quotes.first, management_fee_cop: fee, advance_percent: 50, terms: nil, by: "Ana")
    end

    def client_user(company, email: "laura@aromas.co")
      User.find_by(email:) || User.create!(clerk_id: "user_#{email}", email:, first_name: "Laura", role: "cliente", client_company: company)
    end

    def staff_user(role: "inspector", email: "pedro@kovzu.co")
      User.find_by(email:) || User.create!(clerk_id: "user_#{email}", email:, first_name: "Pedro", role:)
    end

    def pay!(sub_order, kind, amount: nil, confirm_mismatch: false)
      sub_order.register_payment!(kind:, amount_cop: amount || sub_order.expected_payment_cop(kind), paid_on: Date.current,
                                  support: fixture_upload("soporte.pdf", "application/pdf"), confirm_mismatch:, by: "Ana")
    end

    # Propuesta aceptada: el subpedido espera el anticipo.
    def confirmed_sub_order
      sub_order = quoted_sub_order
      send_proposal(sub_order).accept!(user: client_user(sub_order.order.client_company))
      sub_order.reload
    end

    # Anticipo pagado, muestra aprobada y producción terminada: lista para inspeccionar.
    def sub_order_in_inspection
      sub_order = confirmed_sub_order
      pay!(sub_order, "anticipo")
      sample = sub_order.reload.register_sample!(kind: "fisica", notes: nil, photos: [ fixture_upload("muestra.png", "image/png") ], by: "Ana")
      sample.approve!(user: client_user(sub_order.order.client_company))
      sub_order.reload.finish_production!(by: "Ana")
      sub_order.reload
    end

    # Llena el checklist: todo conforme, o no conforme (con foto y severidad) en los ítems indicados.
    def fill_inspection(inspection, nonconforming: {})
      items = inspection.items.to_h do |item|
        severity = nonconforming[item.key]
        [ item.id.to_s, severity ? { "result" => "no_conforme", "severity" => severity, "note" => "Fuera de tolerancia" } : { "result" => "conforme" } ]
      end
      photos = inspection.items.select { |item| nonconforming.key?(item.key) }.to_h { |item| [ item.id.to_s, [ fixture_upload("muestra.png", "image/png") ] ] }
      inspection.record!(items, notes: "Revisión en planta", photos:)
      inspection.reload
    end
  end
end

# Sesión de Clerk simulada para las pruebas de integración: `sign_in_as(user)`.
module ClerkTestSession
  FakeClerk = Struct.new(:user_id) do
    def user? = true
  end

  module ControllerPatch
    private

    def clerk
      (user_id = Thread.current[:kovzu_test_clerk_user_id]) ? FakeClerk.new(user_id) : super
    end
  end

  def sign_in_as(user)
    Thread.current[:kovzu_test_clerk_user_id] = user.clerk_id
  end

  def self.included(base)
    base.teardown { Thread.current[:kovzu_test_clerk_user_id] = nil }
  end
end

ApplicationController.prepend(ClerkTestSession::ControllerPatch)
ActionDispatch::IntegrationTest.include(ClerkTestSession)
