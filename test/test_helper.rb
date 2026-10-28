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
      Category.create!(slug:, name: slug.capitalize, min_lead_days: 5, tech_sheet_template: fields)
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
  end
end
