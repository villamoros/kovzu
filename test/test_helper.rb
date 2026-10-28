ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors, with: :threads)

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
      Category.find_by(slug:) || Category.create!(slug:, name: slug.capitalize, min_lead_days: 5, tech_sheet_template: fields)
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
      User.create!(clerk_id: "user_#{email}", email:, first_name: "Laura", role: "cliente", client_company: company)
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
