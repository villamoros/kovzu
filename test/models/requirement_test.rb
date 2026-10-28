require "test_helper"

class RequirementTest < ActiveSupport::TestCase
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
end
