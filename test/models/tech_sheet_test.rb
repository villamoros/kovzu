require "test_helper"

class TechSheetTest < ActiveSupport::TestCase
  setup do
    @sub_order = start_order.sub_orders.first
    @sheet = @sub_order.current_tech_sheet
  end

  test "marcarla lista exige criterios y campos obligatorios" do
    error = assert_raises(TechSheet::TransitionError) { @sheet.mark_ready!(by: "Ana") }
    assert_match "criterios", error.message

    @sheet.revise!({ acceptance_criteria: "Sin rayones", fields: @sheet.fields.except("material") }, by: "Ana")
    error = assert_raises(TechSheet::TransitionError) { @sheet.mark_ready!(by: "Ana") }
    assert_match "Material", error.message

    @sheet.revise!({ fields: @sheet.fields.merge("material" => "C14") }, by: "Ana")
    @sheet.mark_ready!(by: "Ana")
    assert @sheet.lista?
  end

  test "editar una ficha lista la devuelve a borrador" do
    @sheet.update!(acceptance_criteria: "Sin rayones")
    @sheet.mark_ready!(by: "Ana")

    assert_same @sheet, @sheet.revise!({ acceptance_criteria: "Sin rayones ni manchas" }, by: "Ana")
    assert @sheet.borrador?
  end

  test "una ficha aceptada no se edita: se crea la versión siguiente" do
    @sheet.update!(acceptance_criteria: "Sin rayones")
    @sheet.mark_ready!(by: "Ana")
    @sheet.accept!(role: "cliente", actor_name: "Laura")
    assert @sheet.lista?
    @sheet.accept!(role: "taller", actor_name: "Jorge")
    assert @sheet.aceptada?
    assert_equal 2, @sheet.approvals.count

    @sheet.acceptance_criteria = "Otra cosa"
    assert_not @sheet.save

    next_sheet = @sheet.reload.revise!({ acceptance_criteria: "Sin rayones, con sello" }, by: "Ana")
    assert_equal 2, next_sheet.version
    assert next_sheet.borrador?
    assert_equal @sheet.fields, next_sheet.fields
    assert @sheet.reload.reemplazada?
    assert_equal next_sheet, @sub_order.reload.current_tech_sheet
  end
end
