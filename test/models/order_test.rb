require "test_helper"

class OrderTest < ActiveSupport::TestCase
  test "crear el pedido desde un requerimiento completo arma subpedido y ficha v1 precargada" do
    requirement = create_requirement
    order = start_order(requirement)

    assert_equal "KZ-0001", order.code
    assert order.en_preparacion?
    sheet = order.sub_orders.first.current_tech_sheet
    assert_equal 1, sheet.version
    assert_equal({ "producto" => "Caja plegadiza", "cantidad" => "500", "material" => "Plegadiza C14" }, sheet.fields)
    assert_raises(Requirement::TransitionError) { Order.start_from!(requirement.reload, by: "Ana") }
  end

  test "los códigos siguen la secuencia" do
    category = create_category
    first = start_order(create_requirement(category:))
    second = start_order(create_requirement(category:))

    assert_equal %w[KZ-0001 KZ-0002], [ first.code, second.code ]
    assert_equal "KZ-0002", second.to_param
  end
end
