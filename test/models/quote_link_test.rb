require "test_helper"

class QuoteLinkTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  setup do
    @sub_order = start_order.sub_orders.first
    ready_sheet!(@sub_order)
    @workshop = create_workshop("Cartón Valle", category: @sub_order.category)
    @workshop.update!(email: "taller@cartonvalle.co")
  end

  test "HU-05: pedir cotización le envía el enlace al taller con correo" do
    assert_enqueued_emails(1) { @quote = @sub_order.request_quotes!([ @workshop.id ], by: "Ana").first }
    assert @quote.link_usable?
  end

  test "HU-05: el taller cotiza, acepta la versión de la ficha y ya no puede editar" do
    quote = request_quote

    assert_raises(Quote::TransitionError) { quote.submit_from_link!(offer, accept_sheet: "0") }
    error = assert_raises(ActiveRecord::RecordInvalid) { quote.submit_from_link!(offer.except(:valid_until), accept_sheet: "1") }
    assert_match "Vigencia", error.message
    quote.reload

    quote.submit_from_link!(offer, accept_sheet: "1")

    assert quote.reload.recibida?
    assert_not quote.entered_by_operator?
    approval = quote.approvals.sole
    assert_equal [ "taller", "Cartón Valle", 1 ], [ approval.actor_role, approval.actor_name, approval.version ]
    assert_raises(Quote::TransitionError) { quote.submit_from_link!(offer.merge(price_cop: 1), accept_sheet: "1") }
    assert_equal 1_200_000, quote.reload.price_cop
  end

  test "HU-05: 'No cotizo' deja el motivo para el operador" do
    quote = request_quote
    quote.decline!("Sin capacidad esa semana", by: @workshop.name)

    assert quote.rechazada?
    assert_equal "Sin capacidad esa semana", quote.decline_reason
  end

  test "HU-05: con el enlace vencido pide uno nuevo y el operador lo renueva" do
    quote = request_quote
    quote.update!(link_expires_at: 1.hour.ago)
    old_token = quote.token

    assert_raises(Quote::TransitionError) { quote.submit_from_link!(offer, accept_sheet: "1") }
    quote.request_renewal!
    assert quote.renewal_requested_at
    assert_includes OperatorDashboard.new.attention.map(&:reason), "Un taller pidió un enlace nuevo para cotizar"

    assert_enqueued_emails(1) { quote.renew_link!(by: "Ana") }
    assert quote.link_usable?
    assert_nil quote.renewal_requested_at
    assert_not_equal old_token, quote.token
  end

  test "HU-05: si la ficha cambió, el enlace pide renovarse con la versión vigente" do
    quote = request_quote
    sheet = @sub_order.current_tech_sheet
    sheet.accept!(role: "cliente", actor_name: "Laura")
    sheet.accept!(role: "taller", actor_name: "Cartón Valle")
    new_sheet = sheet.revise!({ "acceptance_criteria" => "Sin rayones ni manchas" }, by: "Ana")
    new_sheet.mark_ready!(by: "Ana")

    assert_not quote.reload.link_usable?
    assert_raises(Quote::TransitionError) { quote.submit_from_link!(offer, accept_sheet: "1") }
    quote.renew_link!(by: "Ana")
    assert_equal new_sheet, quote.tech_sheet
  end

  private

  def request_quote = @sub_order.request_quotes!([ @workshop.id ], by: "Ana").first

  def offer = { price_cop: "1200000", lead_days: "10", conditions: "Anticipo del 50 %", valid_until: (Date.current + 8).to_s }
end
