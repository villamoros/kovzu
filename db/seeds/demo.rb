# Datos de ejemplo para desarrollo: clientes, talleres y pedidos en varios estados.
# Solo se cargan si no hay pedidos todavía.
return if Order.exists?

# Sin correos al sembrar, y los trabajos (como el acta en PDF) en línea.
ActionMailer::Base.perform_deliveries = false
ActiveJob::Base.queue_adapter = :inline

today = Date.current
cats = Category.all.index_by(&:slug)
operator = "Juan Villamoros"

clients = {
  aroma: ClientCompany.create!(name: "Aroma de Café SAS", nit: "901234567-1", segment: "marca", contact_name: "Laura Gómez", contact_email: "laura@aromadecafe.co"),
  ferre: ClientCompany.create!(name: "Ferretería El Tornillo", nit: "805012345-2", segment: "pyme", contact_name: "Andrés Ruiz", contact_email: "compras@eltornillo.co"),
  eventos: ClientCompany.create!(name: "Pacífico Eventos", nit: "900765432-3", segment: "agencia", contact_name: "Valentina Ortiz", contact_email: "produccion@pacificoeventos.co")
}

def workshop!(attrs, capabilities)
  workshop = Workshop.create!(attrs)
  capabilities.each { |cap| workshop.capabilities.create!(cap) }
  workshop
end

verified = { status: "verificado", has_rut: true, e_invoicing: true, visited_at: 20.days.ago, pilot_approved_at: 10.days.ago,
             visit_checklist: Workshop::VISIT_ITEMS.keys.index_with(true) }

workshops = {
  carton: workshop!(verified.merge(name: "Cartón Valle", nit: "900111222-1", level: "confiable", score: 4.6, contact_name: "Óscar Méndez",
                                   whatsapp: "+57 315 000 1122", neighborhood: "Acopi, Yumbo", machines: "Troqueladora plana, pegadora semiautomática"),
                    [ { category: cats["empaques"], processes: "Troquelado, pegado", materials: "Plegadiza, corrugado", min_volume: 200, max_volume: 20_000 } ]),
  lito: workshop!(verified.merge(name: "Litografía Pance", nit: "900333444-2", level: "preferente", score: 4.8, contact_name: "Marcela Díaz",
                                 whatsapp: "+57 318 000 3344", neighborhood: "San Nicolás", machines: "Offset 4 colores, digital, troqueladora de etiquetas"),
                  [ { category: cats["impresion"], processes: "Offset, digital", materials: "Adhesivo, propalcote", min_volume: 100, max_volume: 50_000 },
                    { category: cats["empaques"], processes: "Plegadiza impresa", materials: "Plegadiza", min_volume: 500 } ]),
  maderas: workshop!(verified.merge(name: "Maderas del Sur", nit: "900555666-3", level: "verificado", score: 4.1, contact_name: "Hernán Castillo",
                                    whatsapp: "+57 312 000 5566", neighborhood: "El Guabal", machines: "Router CNC, sierra escuadradora"),
                     [ { category: cats["carpinteria"], processes: "Corte, ensamble, lacado", materials: "MDF, pino, triplex", max_volume: 300 },
                       { category: cats["corte"], processes: "Router CNC", materials: "MDF, acrílico", max_volume: 1_000 } ]),
  alameda: workshop!(verified.merge(name: "Confecciones Alameda", nit: "900777888-4", level: "verificado", score: 3.9, contact_name: "Rosa Quintero",
                                    whatsapp: "+57 317 000 7788", neighborhood: "Alameda", machines: "Bordadora 6 cabezas, fileteadoras"),
                     [ { category: cats["confeccion"], processes: "Confección, bordado", materials: "Algodón, antifluido", min_volume: 24, max_volume: 2_000 } ]),
  laser: workshop!({ name: "Láser Express", nit: "900999000-5", status: "en_verificacion", has_rut: true, e_invoicing: false, contact_name: "Felipe Rojas",
                   whatsapp: "+57 310 000 9900", neighborhood: "Centro", visit_checklist: { "maquinas" => true, "fotos" => true, "visita" => true },
                   visited_at: 3.days.ago, notes: "Pendiente habilitar factura electrónica." },
           [ { category: cats["corte"], processes: "Corte láser", materials: "Acrílico, MDF", max_volume: 5_000 } ]),
  metal: workshop!({ name: "Metálicas JR", status: "prospecto", contact_name: "Jhon Rivas", whatsapp: "+57 311 000 1212", neighborhood: "La Base" },
         [ { category: cats["metalmecanica"], processes: "Corte, doblez, soldadura MIG", materials: "Cold rolled, inoxidable" } ])
}

# Requerimientos en la cola del operador
Requirement.create!(client_company: clients[:eventos], category: cats["carpinteria"], title: "Exhibidor de mesa para feria", quantity: 12,
                    dimensions: "600 × 400 × 900 mm", material: "MDF 15 mm", finish: "Laca blanca", required_on: BusinessDays.add(today, 6),
                    description: "Para la feria de cafés especiales. Con logo en vinilo al frente.", channel: "whatsapp", submitted_at: 1.day.ago)
waiting = Requirement.create!(client_company: clients[:ferre], category: nil, title: "Dotación para 30 empleados", quantity: 30,
                              description: "Camisas tipo polo con logo bordado. No sé qué tela conviene.", channel: "portal", submitted_at: 3.days.ago)
waiting.ask_clarification!("¿Qué tallas necesitas y cuántas de cada una? ¿El logo va en el pecho izquierdo?", by: operator)

# Pedido en preparación: ficha en borrador
req_box = Requirement.create!(client_company: clients[:aroma], category: cats["empaques"], title: "Caja plegadiza con inserto", quantity: 2_000,
                              dimensions: "120 × 80 × 45 mm", material: "Plegadiza C14", finish: "Laminado mate", required_on: BusinessDays.add(today, 15), submitted_at: 2.days.ago)
req_box.mark_complete!(by: operator)
Order.start_from!(req_box, by: operator)

# Pedido cotizando: ficha lista y dos solicitudes
req_labels = Requirement.create!(client_company: clients[:aroma], category: cats["impresion"], title: "Etiquetas adhesivas para bolsas de café", quantity: 5_000,
                                 dimensions: "80 × 50 mm", material: "Adhesivo propalcote", finish: "Laminado mate", required_on: BusinessDays.add(today, 10), submitted_at: 4.days.ago)
req_labels.mark_complete!(by: operator)
labels = Order.start_from!(req_labels, by: operator)
sheet = labels.sub_orders.first.current_tech_sheet
sheet.revise!({ "fields" => sheet.fields.merge("tintas" => "CMYK", "presentacion" => "Rollo"),
                "acceptance_criteria" => "Color dentro de la prueba aprobada; corte ± 1 mm; 5.000 unidades en rollos de 1.000." }, by: operator)
sheet.mark_ready!(by: operator)
labels_quote = labels.sub_orders.first.request_quotes!([ workshops[:lito].id ], by: operator).first

# La cotización llegó por WhatsApp y ya hay propuesta esperando al cliente (HU-07)
seed_file = ->(name, type) { { io: Rails.root.join("db/seeds/files", name).open, filename: name, content_type: type } }
labels_quote.record_by_operator!({ price_cop: 1_450_000, lead_days: 9, conditions: "Incluye troquel. Anticipo del 50 %.", valid_until: today + 10 },
                                 support: seed_file.("cotizacion-whatsapp.png", "image/png"), by: operator)
Proposal.send_for!(labels_quote.reload, management_fee_cop: 150_000, advance_percent: 50, terms: "Precio antes de IVA. Entrega en Cali.", by: operator)

# Pedidos en curso con hitos (uno atrasado)
def running_order!(client, category, workshop, title, quantity, status, start_on, operator, fields)
  req = Requirement.create!(client_company: client, category:, title:, quantity:, submitted_at: start_on - 5, status: "completo", qualified_at: start_on - 4)
  order = Order.create!(client_company: client, requirement: req, status: "en_curso", management_fee_cop: 180_000, confirmed_at: start_on,
                        promised_on: BusinessDays.add(start_on, 14))
  sub = order.sub_orders.create!(category:, workshop:, title:, quantity:, status:, amount_cop: quantity * 900)
  sub.tech_sheets.create!(fields: { "producto" => title, "cantidad" => quantity.to_s }.merge(fields), acceptance_criteria: "Según muestra aprobada.",
                          status: "aceptada", accepted_by_client_at: start_on, accepted_by_workshop_at: start_on)
  sub.plan_milestones!(start_on:)
  AuditEvent.record!(order, "pedido.confirmado", actor: operator)
  sub
end

secondary = running_order!(clients[:aroma], cats["empaques"], workshops[:carton], "Empaque secundario", 1_500, "en_produccion", today - 8, operator,
                           { "material" => "Corrugado E", "dimensiones" => "260 × 180 × 120 mm", "impresion" => "1 tinta", "entrega" => "Plana" })
secondary.milestones.where(kind: %w[anticipo muestra]).find_each { |m| m.complete!(on: m.committed_on) }

stand = running_order!(clients[:eventos], cats["carpinteria"], workshops[:maderas], "Exhibidor de mesa", 20, "muestra_pendiente", today - 10, operator,
                       { "material" => "MDF 15 mm", "dimensiones" => "600 × 400 × 900 mm", "acabado" => "Laca", "armado" => "Armado" })
stand.milestones.find_by(kind: "anticipo").complete!(on: today - 9)
first_sample = stand.register_sample!(kind: "fisica", notes: "Primera muestra en MDF lacado.", photos: [ seed_file.("muestra-exhibidor.png", "image/png") ], by: operator)
first_sample.update_columns(status: "rechazada", comment: "El logo quedó descentrado y la laca tiene grumos.", decided_by: "Valentina Ortiz",
                            decided_at: 4.days.ago, created_at: 6.days.ago)
stand.increment!(:rejection_count)
stand.register_sample!(kind: "fisica", notes: "Logo centrado y segunda mano de laca.", photos: [ seed_file.("muestra-exhibidor.png", "image/png") ], by: operator)

uniforms = running_order!(clients[:ferre], cats["confeccion"], workshops[:alameda], "Dotación bordada", 60, "inspeccion", today - 14, operator,
                          { "material" => "Dril 100 % algodón", "tallas" => "S: 15, M: 25, L: 15, XL: 5", "marcacion" => "Logo bordado en pecho izquierdo, 8 cm" })
uniforms.milestones.where(kind: %w[anticipo muestra produccion]).find_each { |m| m.complete!(on: m.committed_on) }

# Paso 4: pagos, inspecciones, actas y comisiones
inspector = User.find_or_create_by!(clerk_id: "seed_inspector") { |user| user.assign_attributes(first_name: "Pedro", last_name: "Inspector", email: "inspeccion@kovzu.co", role: "inspector") }
workshops[:carton].update!(payment_details: "Bancolombia ahorros 123-456789-00 · Cartón Valle SAS · NIT 900111222-1")
workshops[:maderas].update!(payment_details: "Davivienda corriente 0550-1234-5678 · Maderas del Sur")
workshops[:lito].update!(payment_details: "Banco de Bogotá ahorros 987-65432-1 · Litografía Pance SAS", commission_percent: 9)

support = -> { seed_file.("cotizacion-whatsapp.png", "image/png") }
pay_advance = lambda do |sub, paid_on|
  sub.update_columns(status: "anticipo_pendiente")
  sub.register_payment!(kind: "anticipo", amount_cop: sub.expected_payment_cop(:anticipo), paid_on:, support: support.(), by: operator)
  sub
end
{ secondary => "en_produccion", stand => "muestra_pendiente", uniforms => "inspeccion" }.each do |sub, status|
  pay_advance.(sub, sub.milestones.find_by(kind: "anticipo").committed_on.then { |date| [ date, today ].min })
  sub.update_columns(status:)
end

# Lote inspeccionado y aprobado, con el saldo pagado y entregado. Deja comisión.
def inspected!(sub, inspector, operator, nonconforming: nil, photo: nil)
  sub.update_columns(status: "inspeccion")
  inspection = Inspection.start_for!(sub, by: inspector.name)
  inspection.items.each do |item|
    if item.key == nonconforming
      item.update!(result: "no_conforme", severity: "menor", measurement: "+1,5 mm", note: "Alto interno 1,5 mm por encima de la tolerancia")
      item.photos.attach(photo)
    else
      item.update!(result: "conforme")
    end
  end
  inspection.update!(notes: "Revisión en planta del taller.")
  inspection.close!(result: nonconforming ? "aprobado_con_desviacion" : "aprobado", user: inspector)
end

def delivered!(sub, inspector, operator, paid_on, support)
  inspected!(sub, inspector, operator)
  sub.reload.register_payment!(kind: "saldo", amount_cop: sub.expected_payment_cop(:saldo), paid_on:, support:, by: operator)
  sub.reload.deliver!(by: operator)
  sub
end

displays = running_order!(clients[:eventos], cats["corte"], workshops[:maderas], "Letreros en MDF cortados en CNC", 40, "en_produccion", today - 60, operator,
                          { "material" => "MDF 9 mm", "dimensiones" => "400 × 300 mm", "proceso" => "Router CNC" })
displays.update_columns(amount_cop: 2_400_000)
pay_advance.(displays, today - 58)
displays.update_columns(status: "en_produccion")
delivered!(displays, inspector, operator, today - 40, support.())

seasonal = running_order!(clients[:eventos], cats["impresion"], workshops[:lito], "Etiquetas de temporada", 3_000, "en_produccion", today - 20, operator,
                          { "material" => "Adhesivo propalcote", "dimensiones" => "60 × 40 mm", "tintas" => "CMYK" })
pay_advance.(seasonal, today - 18)
seasonal.update_columns(status: "en_produccion")
delivered!(seasonal, inspector, operator, today - 2, support.())

# Corte del mes del letrero: facturado y vencido hace más de 15 días → Maderas del Sur en mora (RN-09)
cut = CommissionCut.run!(month: (today - 40).beginning_of_month, by: operator)
cut.invoice!(workshops[:maderas], number: "KZ-FE-0007", invoiced_on: today - 25, due_on: today - 20, by: operator)

# Lote con una desviación menor esperando la decisión del cliente (HU-13)
bags = running_order!(clients[:aroma], cats["empaques"], workshops[:carton], "Bolsas kraft con manija", 800, "en_produccion", today - 15, operator,
                      { "material" => "Kraft 120 g", "dimensiones" => "260 × 120 × 320 mm", "impresion" => "1 tinta" })
pay_advance.(bags, today - 14)
bags.milestones.where(kind: %w[anticipo muestra produccion]).find_each { |m| m.complete!(on: [ m.committed_on, today ].min) }
inspected!(bags, inspector, operator, nonconforming: "medidas", photo: seed_file.("muestra-exhibidor.png", "image/png"))
