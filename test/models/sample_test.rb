require "test_helper"

class SampleTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  setup do
    sub_order = quoted_sub_order
    @client = client_user(sub_order.order.client_company)
    send_proposal(sub_order).accept!(user: @client)
    @sub_order = sub_order.reload
  end

  test "registrar la muestra exige fotos y avisa al cliente" do
    assert_raises(ActiveRecord::RecordInvalid) { @sub_order.register_sample!(kind: "fisica", notes: nil, photos: [], by: "Ana") }

    sample = nil
    assert_enqueued_emails(1) { sample = register_sample }
    assert sample.por_revisar?
    assert @sub_order.reload.muestra_pendiente?
    assert @sub_order.order.en_curso?
    assert_not @sub_order.can_register_sample?
  end

  test "HU-09: aprobarla la deja como muestra patrón y el subpedido pasa a producción" do
    sample = register_sample

    sample.approve!(user: @client)

    assert sample.aprobada?
    assert @sub_order.reload.en_produccion?
    assert @sub_order.milestones.find_by(kind: "muestra").done?
    assert_equal "aceptada", sample.approvals.sole.decision
  end

  test "HU-09: rechazarla exige comentario y reprograma la muestra" do
    sample = register_sample
    muestra = @sub_order.milestones.find_by(kind: "muestra")

    assert_raises(Sample::TransitionError) { sample.reject!("", user: @client) }
    sample.reject!("El logo quedó descentrado", user: @client)

    assert sample.rechazada?
    assert_equal 1, @sub_order.reload.rejection_count
    muestra.reload
    assert muestra.rescheduled?
    assert_equal BusinessDays.add(Date.current, 3), muestra.committed_on
    assert_equal "taller", muestra.rescheduled_by
    assert_match "descentrado", muestra.reschedule_reason
    assert @sub_order.can_register_sample?
  end

  test "HU-09: el tercer rechazo alerta al operador" do
    3.times { |index| register_sample.reject!("Ajuste #{index + 1}", user: @client) }

    assert_includes OperatorDashboard.new.attention.map(&:reason), "3 muestras rechazadas: revisar ficha o taller"
  end

  test "HU-09: sin respuesta en 3 días hábiles aparece en el tablero" do
    sample = register_sample
    sample.update_columns(created_at: BusinessDays.ago(3).to_time)

    assert sample.overdue?
    assert_includes Sample.waiting_too_long, sample
    assert_includes OperatorDashboard.new.attention.map(&:reason), "Cliente sin responder la muestra"
  end

  private

  def register_sample
    @sub_order.register_sample!(kind: "fisica", notes: "Primera muestra", photos: [ fixture_upload("muestra.png", "image/png") ], by: "Ana")
  end
end
