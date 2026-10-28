require "test_helper"

class QuoteTest < ActiveSupport::TestCase
  setup do
    @sub_order = start_order.sub_orders.first
    ready_sheet!(@sub_order)
    @quote = @sub_order.request_quotes!([ create_workshop("Cartón Valle", category: @sub_order.category).id ], by: "Ana").first
  end

  test "HU-05: la cotización cargada por el operador exige soporte y queda marcada" do
    assert_raises(Quote::TransitionError) { @quote.record_by_operator!({ price_cop: 900_000, lead_days: 10 }, support: nil, by: "Ana") }

    @quote.record_by_operator!({ price_cop: 900_000, lead_days: 10 }, support: fixture_upload("soporte.pdf", "application/pdf"), by: "Ana")

    assert @quote.recibida?
    assert @quote.entered_by_operator?
    assert @quote.support.attached?
    assert_raises(Quote::TransitionError) { @quote.decline!("Sin capacidad", by: "Ana") }
  end

  test "el taller que no cotiza deja su motivo" do
    assert_raises(Quote::TransitionError) { @quote.decline!("", by: "Ana") }
    @quote.decline!("Sin capacidad esa semana", by: "Ana")

    assert @quote.rechazada?
    assert_equal "Sin capacidad esa semana", @quote.decline_reason
  end
end
