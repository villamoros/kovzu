require "test_helper"

class InspectionTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include ActionMailer::TestHelper

  setup do
    @sub_order = sub_order_in_inspection
    @inspector = staff_user
    @client = client_user(@sub_order.order.client_company)
  end

  test "CU-07: producción terminada deja el lote en inspección" do
    assert @sub_order.inspeccion?
    assert @sub_order.milestones.find_by(kind: "produccion").done?
  end

  test "HU-12: abre con el checklist de la categoría, los criterios de la ficha y la muestra según el lote" do
    inspection = start

    assert_equal %w[medidas cantidad criterios], inspection.items.map(&:key)
    assert_equal "± 1 mm", inspection.items.first.tolerance
    assert_equal "Sin rayones", inspection.criteria
    assert_equal 500, inspection.lot_size
    assert_equal 50, inspection.sample_size
    assert_equal inspection, Inspection.start_for!(@sub_order, by: "Pedro"), "no abre una segunda inspección"
  end

  test "HU-12: no cierra con ítems sin resultado" do
    inspection = start
    error = assert_raises(Inspection::TransitionError) { inspection.close!(result: "aprobado", user: @inspector) }
    assert_match "Falta el resultado", error.message
    assert inspection.reload.abierta?
  end

  test "HU-12: un ítem no conforme exige foto y severidad" do
    inspection = start
    items = inspection.items.to_h { |item| [ item.id.to_s, { "result" => item.key == "medidas" ? "no_conforme" : "conforme" } ] }
    inspection.record!(items, notes: nil)

    error = assert_raises(Inspection::TransitionError) { inspection.reload.close!(result: "rechazado", rework_due_on: Date.current + 7, user: @inspector) }
    assert_match "indica la severidad", error.message
    assert_match "adjunta al menos una foto", error.message
  end

  test "HU-12 / HU-13: aprobado queda inmutable, habilita el saldo y envía el acta" do
    inspection = fill_inspection(start)

    assert_enqueued_with(job: InspectionReportJob) do
      assert_enqueued_emails(1) { inspection.close!(result: "aprobado", user: @inspector) }
    end

    assert inspection.cerrada?
    assert_equal [ "Pedro", @inspector ], [ inspection.closed_by, inspection.closed_by_user ]
    assert inspection.closed_at
    assert @sub_order.reload.aprobado?
    assert @sub_order.balance_enabled?
    assert @sub_order.milestones.find_by(kind: "inspeccion").done?

    assert_raises(ActiveRecord::RecordInvalid) { inspection.update!(result: "rechazado") }
    assert_raises(ActiveRecord::ReadOnlyRecord) { inspection.items.first.update!(result: "no_conforme") }
    assert_raises(Inspection::TransitionError) { inspection.record!({}, notes: "otra cosa") }
  end

  test "un lote con no conformidades no queda aprobado sin desviación, y una crítica no admite desviación" do
    inspection = fill_inspection(start, nonconforming: { "medidas" => "critica" })

    assert_raises(Inspection::TransitionError) { inspection.close!(result: "aprobado", user: @inspector) }
    error = assert_raises(Inspection::TransitionError) { inspection.close!(result: "aprobado_con_desviacion", user: @inspector) }
    assert_match "crítica", error.message
  end

  test "HU-13: con desviación, el cliente la acepta y se habilita el saldo" do
    inspection = fill_inspection(start, nonconforming: { "medidas" => "menor" })
    inspection.close!(result: "aprobado_con_desviacion", user: @inspector)

    assert @sub_order.reload.aprobado_con_desviacion?
    assert_not @sub_order.balance_enabled?
    assert_includes OperatorDashboard.new.attention.map(&:reason), "Desviación esperando la decisión del cliente"

    inspection.accept_deviation!(user: @client)

    assert_equal "aceptada", inspection.deviation_status
    assert_equal "aceptada", inspection.approvals.sole.decision
    assert @sub_order.reload.balance_enabled?
  end

  test "HU-13: si el cliente rechaza la desviación, cuenta como rechazo y va a reproceso" do
    inspection = fill_inspection(start, nonconforming: { "medidas" => "menor" })
    inspection.close!(result: "aprobado_con_desviacion", user: @inspector)

    assert_raises(Inspection::TransitionError) { inspection.reject_deviation!("", user: @client) }
    inspection.reject_deviation!("Se nota en el punto de venta", user: @client)

    assert inspection.rejection?
    assert @sub_order.reload.reproceso?
    assert_not @sub_order.balance_enabled?
  end

  test "HU-13 / RN-06: rechazado bloquea saldo y despacho; el segundo rechazo escala" do
    inspection = fill_inspection(start, nonconforming: { "medidas" => "mayor" })
    assert_raises(Inspection::TransitionError) { inspection.close!(result: "rechazado", user: @inspector) }
    inspection.close!(result: "rechazado", rework_due_on: BusinessDays.add(Date.current, 5), user: @inspector)

    assert @sub_order.reload.reproceso?
    assert_raises(SubOrder::TransitionError) { pay!(@sub_order, "saldo") }
    milestone = @sub_order.milestones.find_by(kind: "inspeccion")
    assert_equal "taller", milestone.rescheduled_by
    assert_equal BusinessDays.add(inspection.rework_due_on, 1), milestone.committed_on

    @sub_order.finish_production!(by: "Ana")
    second = fill_inspection(start, nonconforming: { "medidas" => "mayor" })
    assert_equal inspection, second.reinspection_of
    second.close!(result: "rechazado", rework_due_on: BusinessDays.add(Date.current, 5), user: @inspector)

    assert @sub_order.reload.escalado?
    assert @sub_order.order.escalado?
    assert_includes OperatorDashboard.new.attention.map(&:reason), "Segundo rechazo del lote: decidir reasignar, descontar o cancelar"
  end

  test "HU-13: el acta en PDF se adjunta y se envía a cliente y taller" do
    @sub_order.workshop.update!(email: "taller@cartonvalle.co")
    inspection = fill_inspection(start, nonconforming: { "medidas" => "menor" })
    inspection.close!(result: "aprobado_con_desviacion", user: @inspector)

    assert_emails(2) { InspectionReportJob.perform_now(inspection) }

    assert inspection.reload.report.attached?
    assert inspection.report_sent_at
    pdf = inspection.report.download
    assert pdf.start_with?("%PDF")
    client_mail, workshop_mail = ActionMailer::Base.deliveries.last(2)
    assert_equal [ "laura@aromas.co" ], client_mail.to
    assert_equal [ "taller@cartonvalle.co" ], workshop_mail.to
    assert_equal inspection.report_filename, client_mail.attachments.first.filename
    assert_no_match "laura@aromas.co", workshop_mail.body.encoded
  end

  test "HU-13: si falla el correo al taller, el reintento no le vuelve a escribir al cliente" do
    @sub_order.workshop.update!(email: "taller@cartonvalle.co")
    inspection = fill_inspection(start)
    inspection.close!(result: "aprobado", user: @inspector)

    failing_workshop_mail = Module.new do
      def self.delivering_email(mail) = (raise "Resend no responde" if mail.to == [ "taller@cartonvalle.co" ])
    end
    ActionMailer::Base.register_interceptor(failing_workshop_mail)
    begin
      assert_enqueued_with(job: InspectionReportJob) do
        assert_emails(1) { InspectionReportJob.perform_now(inspection) }
      end
    ensure
      ActionMailer::Base.unregister_interceptor(failing_workshop_mail)
    end
    inspection.reload
    assert inspection.client_report_sent_at
    assert_nil inspection.workshop_report_sent_at
    assert_nil inspection.report_sent_at

    assert_emails(1) { InspectionReportJob.perform_now(inspection) }
    assert_equal [ "taller@cartonvalle.co" ], ActionMailer::Base.deliveries.last.to
    assert inspection.reload.report_sent_at

    assert_no_emails { InspectionReportJob.perform_now(inspection) }
  end

  private

  def start = Inspection.start_for!(@sub_order, by: "Pedro")
end
