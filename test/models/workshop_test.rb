require "test_helper"

class WorkshopTest < ActiveSupport::TestCase
  setup { @category = create_category }

  test "un prospecto pasa a verificación solo con el checklist completo" do
    workshop = create_workshop("Cartones del Sur", status: "prospecto")

    error = assert_raises(Workshop::TransitionError) { workshop.start_verification!(by: "Ana") }
    assert_match "RUT activo", error.message

    workshop.update!(has_rut: true, e_invoicing: true, visit_checklist: { "maquinas" => "1", "fotos" => "1", "visita" => "1" })
    workshop.start_verification!(by: "Ana")

    assert workshop.en_verificacion?
    assert workshop.visited_at
    assert_equal "taller.en_verificacion", workshop.audit_events.last.action
  end

  test "RN-02: no queda verificado sin RUT y factura electrónica" do
    workshop = create_workshop("Maderas Pance", status: "en_verificacion")

    assert_raises(Workshop::TransitionError) { workshop.approve_pilot!(by: "Ana") }

    workshop.status = "verificado"
    assert_not workshop.valid?
    assert_includes workshop.errors[:status], "verificado exige RUT activo y factura electrónica"
  end

  test "aprobar el piloto lo deja verificado con nivel inicial" do
    workshop = create_workshop("Maderas Pance", status: "en_verificacion")
    workshop.update!(has_rut: true, e_invoicing: true)

    workshop.approve_pilot!(by: "Ana")

    assert workshop.verificado?
    assert_equal "verificado", workshop.level
    assert workshop.pilot_approved_at
  end

  test "pausar y retirar exigen motivo" do
    workshop = create_workshop("Confecciones Alameda")

    assert_raises(Workshop::TransitionError) { workshop.pause!(reason: " ", by: "Ana") }
    workshop.pause!(reason: "Dos rechazos seguidos", by: "Ana")
    assert workshop.pausado?
    assert_equal "Dos rechazos seguidos", workshop.status_reason

    workshop.resume!(by: "Ana")
    assert workshop.verificado?
    assert_nil workshop.status_reason

    assert_raises(Workshop::TransitionError) { workshop.retire!(reason: "", by: "Ana") }
    workshop.retire!(reason: "Cerró el taller", by: "Ana")
    assert workshop.retirado?
  end

  test "RN-01 y HU-04: candidatos verificados, de la categoría y el volumen, ordenados por nivel y puntaje" do
    other = create_category(slug: "corte")
    order = start_order(create_requirement(category: @category, quantity: 500))
    sub_order = order.sub_orders.first

    good = create_workshop("Bueno", category: @category, level: "confiable", score: 4.2)
    best = create_workshop("Mejor", category: @category, level: "preferente", score: 3.9)
    open_range = create_workshop("Sin límite", category: @category, score: 4.8)
    create_workshop("Prospecto", category: @category, status: "prospecto")
    create_workshop("Pausado", category: @category, status: "pausado")
    create_workshop("Otra categoría", category: other)
    create_workshop("Muy pequeño", category: @category, max_volume: 200)
    create_workshop("Muy grande", category: @category, min_volume: 1_000)

    assert_equal [ best, good, open_range ], Workshop.candidates_for(sub_order).to_a
  end

  test "el checklist de visita guarda solo claves conocidas como booleanos" do
    workshop = create_workshop("Láser Express", status: "prospecto")
    workshop.update!(visit_checklist: { "maquinas" => "1", "fotos" => "0", "otra" => "1" })

    assert_equal({ "maquinas" => true, "fotos" => false }, workshop.reload.visit_checklist)
  end
end
