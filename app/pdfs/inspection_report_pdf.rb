# Acta de inspección en PDF (HU-13, RF-20): resultado, muestreo, mediciones y fotos.
# No incluye datos de contacto del cliente, porque también se le envía al taller.
class InspectionReportPdf
  include ActionView::Helpers::NumberHelper

  INK = "0B1F33".freeze
  MUTED = "4A5A6A".freeze
  LINE = "DAD8CF".freeze
  GROUND = "F4F3EE".freeze
  LIME = "C8F03C".freeze
  TONES = { success: "1F7A4D", warning: "9A5B00", danger: "B42318", neutral: MUTED }.freeze
  FONT_DIR = Rails.root.join("vendor/fonts")
  EMBEDDABLE = %w[image/jpeg image/png].freeze
  MAX_PHOTOS = 12

  def initialize(inspection)
    @inspection = inspection
    @sub_order = inspection.sub_order
  end

  def render
    pdf = Prawn::Document.new(page_size: "A4", margin: [ 48, 48, 56, 48 ], info: { Title: "Acta de inspección #{@inspection.order.code}", Creator: "KOVZU" })
    setup_fonts(pdf)
    header(pdf)
    summary(pdf)
    sampling(pdf)
    checklist(pdf)
    criteria_and_notes(pdf)
    photos(pdf)
    footer(pdf)
    pdf.render
  end

  private

  def setup_fonts(pdf)
    pdf.font_families.update("Inter" => { normal: FONT_DIR.join("Inter-Regular.ttf").to_s, bold: FONT_DIR.join("Inter-SemiBold.ttf").to_s })
    pdf.font "Inter", size: 10
    pdf.default_leading 2
    pdf.fill_color INK
  end

  def header(pdf)
    pdf.text "KOVZU", style: :bold, size: 13, character_spacing: 2
    pdf.move_down 18
    pdf.text "Acta de inspección", style: :bold, size: 22
    pdf.text [ "Pedido #{@inspection.order.code}", "Inspección #{@inspection.number}", (@inspection.reinspection? ? "Reinspección" : nil) ].compact.join(" · "),
             color: MUTED
    pdf.move_down 14
    tone = TONES.fetch(@inspection.result_tone, MUTED)
    pdf.fill_color tone
    pdf.fill_rounded_rectangle [ 0, pdf.cursor ], pdf.bounds.width, 34, 8
    pdf.fill_color "FFFFFF"
    pdf.text_box "Resultado: #{@inspection.result_label}", at: [ 14, pdf.cursor - 10 ], size: 13, style: :bold
    pdf.fill_color INK
    pdf.move_down 48
  end

  def summary(pdf)
    rows = [
      [ "Producto", @sub_order.title ],
      [ "Categoría", @sub_order.category.name ],
      [ "Taller", @sub_order.workshop&.name || "—" ],
      [ "Ficha técnica", @inspection.tech_sheet_version ? "Versión #{@inspection.tech_sheet_version}" : "—" ],
      [ "Inspector", @inspection.closed_by ],
      [ "Cierre", I18n.l(@inspection.closed_at, format: :long) ]
    ]
    rows << [ "Reproceso hasta", I18n.l(@inspection.rework_due_on, format: :long) ] if @inspection.rework_due_on
    if @inspection.deviation_status
      decision = { "pendiente" => "Esperando la decisión del cliente", "aceptada" => "Aceptada por el cliente", "rechazada" => "Rechazada por el cliente" }
      rows << [ "Desviación", decision[@inspection.deviation_status] ]
    end
    key_value_table(pdf, rows)
  end

  def sampling(pdf)
    section(pdf, "Muestreo")
    lot = @inspection.lot_size
    text = if lot.to_i.positive?
      "Lote de #{number_with_delimiter(lot, delimiter: '.')} unidades: se revisaron #{number_with_delimiter(@inspection.sample_size, delimiter: '.')} " \
        "(tabla fija ISO 2859-1, nivel general II, lote #{SamplingPlan.range_label(lot)})."
    else
      "Sin tamaño de lote registrado."
    end
    pdf.text text
  end

  def checklist(pdf)
    section(pdf, "Checklist")
    data = [ [ "Ítem", "Tolerancia", "Medición", "Resultado", "Severidad", "Nota" ] ]
    @inspection.items.each do |item|
      data << [ item.label, item.tolerance.presence || "—", item.measurement.presence || "—", item.result_label || "—", item.severity_label || "—", item.note.presence || "" ]
    end
    pdf.table(data, header: true, width: pdf.bounds.width, column_widths: { 0 => 120, 1 => 64, 2 => 64, 3 => 62, 4 => 58 },
                    cell_style: { size: 8.5, border_color: LINE, border_width: 0.5, padding: [ 5, 6 ], text_color: INK }) do |table|
      table.row(0).font_style = :bold
      table.row(0).background_color = GROUND
      @inspection.items.each_with_index do |item, index|
        table.row(index + 1).columns(3).text_color = TONES[:danger] if item.no_conforme?
      end
    end
  end

  def criteria_and_notes(pdf)
    if @inspection.criteria.present?
      section(pdf, "Criterios de aceptación de la ficha")
      pdf.text @inspection.criteria
    end
    if @inspection.notes.present?
      section(pdf, "Observaciones")
      pdf.text @inspection.notes
    end
    return unless @inspection.deviation_comment.present?

    section(pdf, "Comentario del cliente sobre la desviación")
    pdf.text @inspection.deviation_comment
  end

  def photos(pdf)
    attachments = @inspection.items.flat_map { |item| item.photos.map { |photo| [ item, photo ] } }
    return if attachments.empty?

    pdf.start_new_page if pdf.cursor < 240
    section(pdf, "Fotos")
    embeddable, others = attachments.partition { |_, photo| photo.content_type.in?(EMBEDDABLE) }
    width = (pdf.bounds.width - 16) / 2
    embeddable.first(MAX_PHOTOS).each_slice(2) do |pair|
      pdf.start_new_page if pdf.cursor < 200
      top = pdf.cursor
      pair.each_with_index do |(item, photo), index|
        pdf.bounding_box([ index * (width + 16), top ], width:, height: 190) do
          photo.blob.open { |file| pdf.image file.path, fit: [ width, 164 ] }
          pdf.move_down 4
          pdf.text item.label, size: 8, color: MUTED
        end
      end
      pdf.move_down 12
    end
    names = others.map { |item, photo| "#{item.label}: #{photo.filename}" }
    names += embeddable.drop(MAX_PHOTOS).map { |item, photo| "#{item.label}: #{photo.filename}" }
    pdf.text "Otras fotos en KOVZU: #{names.join(', ')}", size: 8, color: MUTED if names.any?
  end

  def footer(pdf)
    pdf.repeat(:all) do
      pdf.bounding_box([ 0, -18 ], width: pdf.bounds.width, height: 20) do
        pdf.stroke_color LINE
        pdf.stroke_horizontal_rule
        pdf.move_down 6
        pdf.text "Acta inmutable generada por KOVZU el #{I18n.l(@inspection.closed_at, format: :long)} · Red de manufactura verificada · Cali",
                 size: 7.5, color: MUTED
      end
    end
  end

  def section(pdf, title)
    pdf.move_down 18
    pdf.text title, style: :bold, size: 12
    pdf.move_down 6
  end

  def key_value_table(pdf, rows)
    pdf.table(rows, width: pdf.bounds.width, column_widths: { 0 => 120 },
                    cell_style: { size: 9.5, borders: [ :bottom ], border_color: LINE, border_width: 0.5, padding: [ 6, 0 ] }) do |table|
      table.column(0).text_color = MUTED
    end
  end
end
