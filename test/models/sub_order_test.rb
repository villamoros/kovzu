require "test_helper"

class SubOrderTest < ActiveSupport::TestCase
  setup do
    @sub_order = start_order.sub_orders.first
    @category = @sub_order.category
    @workshops = 4.times.map { |index| create_workshop("Taller #{index + 1}", category: @category) }
  end

  test "pedir cotizaciones exige la ficha lista" do
    error = assert_raises(SubOrder::TransitionError) { @sub_order.request_quotes!([ @workshops.first.id ], by: "Ana") }
    assert_match "ficha", error.message
  end

  test "HU-04: entre 1 y 3 talleres elegibles, y el pedido pasa a cotizando" do
    ready_sheet!

    assert_raises(SubOrder::TransitionError) { @sub_order.request_quotes!([], by: "Ana") }
    assert_raises(SubOrder::TransitionError) { @sub_order.request_quotes!(@workshops.map(&:id), by: "Ana") }

    prospect = create_workshop("Prospecto", category: @category, status: "prospecto")
    error = assert_raises(SubOrder::TransitionError) { @sub_order.request_quotes!([ prospect.id ], by: "Ana") }
    assert_match "Prospecto", error.message

    quotes = @sub_order.request_quotes!(@workshops.first(2).map(&:id), by: "Ana")
    assert_equal 2, quotes.size
    assert quotes.all? { |quote| quote.token.present? && quote.link_expires_at > 4.days.from_now }
    assert @sub_order.cotizando?
    assert @sub_order.order.cotizando?

    error = assert_raises(SubOrder::TransitionError) { @sub_order.request_quotes!(@workshops.last(2).map(&:id), by: "Ana") }
    assert_match "máximo", error.message
  end

  test "los hitos estándar se planean en días hábiles" do
    milestones = @sub_order.plan_milestones!(start_on: Date.new(2026, 10, 30))

    assert_equal %w[anticipo muestra produccion inspeccion despacho], milestones.map(&:kind)
    assert_equal Date.new(2026, 11, 2), milestones.first.committed_on
    assert milestones.none? { |milestone| milestone.committed_on.saturday? || milestone.committed_on.sunday? }
  end

  private

  def ready_sheet!
    sheet = @sub_order.current_tech_sheet
    sheet.update!(acceptance_criteria: "Sin rayones")
    sheet.mark_ready!(by: "Ana")
  end
end
