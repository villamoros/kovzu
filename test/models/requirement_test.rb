require "test_helper"

class RequirementTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  test "pedir aclaración y registrar la respuesta deja el historial" do
    requirement = create_requirement

    requirement.ask_clarification!("¿Qué tamaño de frasco?", by: "Ana")
    assert requirement.esperando_cliente?
    assert_raises(Requirement::TransitionError) { requirement.mark_complete!(by: "Ana") }

    requirement.record_answer!("Frasco de 30 ml", by: "Laura")
    assert requirement.en_revision?
    assert_equal %w[operador cliente], requirement.messages.map(&:author_role)
  end

  test "marcarlo completo exige categoría" do
    requirement = create_requirement(category: nil)

    error = assert_raises(Requirement::TransitionError) { requirement.mark_complete!(by: "Ana") }
    assert_match "categoría", error.message
  end

  test "no viable exige motivo y cierra el requerimiento" do
    requirement = create_requirement

    assert_raises(Requirement::TransitionError) { requirement.mark_not_viable!("", by: "Ana") }
    requirement.mark_not_viable!("Ningún taller trabaja ese material", by: "Ana")

    assert requirement.no_viable?
    assert_raises(Requirement::TransitionError) { requirement.mark_not_viable!("Otra vez", by: "Ana") }
  end

  test "fecha ajustada cuando pide menos días que el plazo mínimo de la categoría" do
    monday = Time.zone.local(2026, 10, 26, 9)
    requirement = create_requirement(submitted_at: monday, required_on: Date.new(2026, 10, 29))

    assert requirement.tight_deadline?
    requirement.required_on = Date.new(2026, 11, 2)
    assert_not requirement.tight_deadline?
  end

  test "HU-01: desde el portal exige los obligatorios de la plantilla y avisa por correo" do
    category = create_category(fields: [
      { "key" => "producto", "label" => "Producto", "required" => true },
      { "key" => "material", "label" => "Material", "required" => true },
      { "key" => "tintas", "label" => "Tintas", "required" => true }
    ])
    requirement = ClientCompany.create!(name: "Aromas").requirements.build(category:, title: "Etiquetas", quantity: 500)

    assert_raises(ActiveRecord::RecordInvalid) { requirement.submit_from_portal!(by: "Laura") }
    assert_includes requirement.errors.full_messages, "Material no puede estar en blanco"
    assert_includes requirement.errors.full_messages, "Tintas no puede estar en blanco"

    requirement.assign_attributes(material: "Propalcote", details: { "tintas" => "CMYK", "otra" => " " })
    assert_enqueued_emails(1) { requirement.submit_from_portal!(by: "Laura") }
    assert requirement.en_revision?
    assert_equal "portal", requirement.channel
    assert_equal({ "tintas" => "CMYK" }, requirement.details)
  end

  test "HU-01: sin categoría pide una descripción" do
    requirement = ClientCompany.create!(name: "Aromas").requirements.build(title: "Algo", quantity: 10)

    assert_not requirement.valid?(:portal)
    assert requirement.errors[:description].any?
  end

  test "HU-01: rechaza archivos de formato no admitido" do
    requirement = create_requirement
    requirement.files.attach(fixture_upload("notas.txt", "text/plain"))
    requirement.files.attach(fixture_upload("plano.dxf", "application/dxf"))

    assert_not requirement.valid?
    assert_equal 1, requirement.errors[:files].size
    assert_match "notas.txt", requirement.errors[:files].first
  end
end
