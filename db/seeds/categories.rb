# Las seis categorías de arranque con sus plantillas de ficha técnica e inspección.
# Idempotente: se puede correr varias veces.

def field(key, label, required: false, kind: "text", options: nil)
  { "key" => key, "label" => label, "required" => required, "kind" => kind, "options" => options }.compact
end

def check(key, label, tolerance = nil)
  { "key" => key, "label" => label, "tolerance" => tolerance }.compact
end

COMMON_FIELDS = [
  field("producto", "Producto", required: true),
  field("cantidad", "Cantidad (unidades)", required: true, kind: "number")
].freeze

CATEGORIES = [
  {
    slug: "corte", name: "Corte y conformado", description: "Láser, CNC, troquel", min_lead_days: 5,
    fields: [
      field("material", "Material y espesor", required: true),
      field("dimensiones", "Dimensiones (mm)", required: true),
      field("proceso", "Proceso", required: true, kind: "select", options: [ "Corte láser", "Router CNC", "Troquelado", "Plasma" ]),
      field("archivo", "Archivo vectorial", kind: "select", options: [ "DXF", "AI", "SVG", "PDF", "Por elaborar" ]),
      field("acabado", "Acabado de borde"),
      field("tolerancia", "Tolerancia (mm)")
    ],
    checks: [ check("medidas", "Medidas contra el plano", "± 0,5 mm"), check("bordes", "Bordes sin quemaduras ni rebabas"),
              check("espesor", "Espesor del material"), check("cantidad", "Cantidad completa") ]
  },
  {
    slug: "impresion", name: "Impresión y etiquetas", description: "Impresión, adhesivos", min_lead_days: 4,
    fields: [
      field("material", "Sustrato", required: true),
      field("dimensiones", "Medida final (mm)", required: true),
      field("tintas", "Tintas", required: true, kind: "select", options: [ "CMYK", "CMYK + Pantone", "1 tinta", "2 tintas" ]),
      field("acabado", "Acabado", kind: "select", options: [ "Ninguno", "Laminado mate", "Laminado brillante", "Barniz UV" ]),
      field("presentacion", "Presentación", kind: "select", options: [ "Rollo", "Hojas", "Unidades sueltas" ]),
      field("arte", "Versión de arte aprobada")
    ],
    checks: [ check("color", "Color contra la prueba aprobada"), check("registro", "Registro de tintas"),
              check("corte", "Corte y troquel", "± 1 mm"), check("adherencia", "Adherencia del adhesivo"), check("cantidad", "Cantidad completa") ]
  },
  {
    slug: "empaques", name: "Empaques", description: "Cartón, papel, insertos", min_lead_days: 7,
    fields: [
      field("material", "Cartón o papel y calibre", required: true),
      field("dimensiones", "Medidas internas L × A × H (mm)", required: true),
      field("impresion", "Impresión", kind: "select", options: [ "Sin impresión", "1 tinta", "Full color" ]),
      field("acabado", "Acabado", kind: "select", options: [ "Ninguno", "Laminado mate", "Laminado brillante", "Barniz UV", "Hot stamping" ]),
      field("inserto", "Inserto"),
      field("entrega", "Entrega", kind: "select", options: [ "Plana", "Armada" ])
    ],
    checks: [ check("medidas", "Medidas internas", "± 1 mm"), check("plegado", "Plegado y resistencia"),
              check("impresion", "Impresión contra el arte"), check("encolado", "Encolado"), check("cantidad", "Cantidad completa") ]
  },
  {
    slug: "confeccion", name: "Confección y bordado", description: "Textil, dotación, bordado", min_lead_days: 10,
    fields: [
      field("material", "Tela y composición", required: true),
      field("tallas", "Tallas y cantidades por talla", required: true, kind: "textarea"),
      field("colores", "Colores"),
      field("marcacion", "Bordado o estampado (ubicación y tamaño)", kind: "textarea"),
      field("etiquetas", "Etiquetas"),
      field("acabado", "Empaque individual")
    ],
    checks: [ check("medidas", "Medidas por talla", "± 1 cm"), check("costuras", "Costuras y remates"),
              check("marcacion", "Ubicación y densidad del bordado"), check("color", "Color contra la muestra"), check("cantidad", "Cantidad por talla") ]
  },
  {
    slug: "carpinteria", name: "Carpintería", description: "Piezas, exhibidores", min_lead_days: 10,
    fields: [
      field("material", "Madera o tablero", required: true),
      field("dimensiones", "Dimensiones (mm)", required: true),
      field("acabado", "Acabado", kind: "select", options: [ "Natural", "Laca", "Tinte", "Pintura", "Melamina" ]),
      field("herrajes", "Herrajes"),
      field("armado", "Entrega", kind: "select", options: [ "Armado", "Para armar" ])
    ],
    checks: [ check("medidas", "Medidas", "± 2 mm"), check("escuadra", "Escuadra y estabilidad"),
              check("acabado", "Acabado sin defectos"), check("herrajes", "Herrajes completos y firmes"), check("cantidad", "Cantidad completa") ]
  },
  {
    slug: "metalmecanica", name: "Metalmecánica liviana", description: "Piezas y componentes", min_lead_days: 10,
    fields: [
      field("material", "Material y calibre", required: true),
      field("dimensiones", "Dimensiones o plano", required: true),
      field("procesos", "Procesos", kind: "textarea"),
      field("acabado", "Acabado", kind: "select", options: [ "Sin acabado", "Pintura electrostática", "Galvanizado", "Cromado" ]),
      field("tolerancia", "Tolerancias")
    ],
    checks: [ check("medidas", "Medidas contra el plano"), check("soldadura", "Soldaduras continuas y limpias"),
              check("acabado", "Adherencia y uniformidad del acabado"), check("rebabas", "Sin rebabas ni bordes cortantes"), check("cantidad", "Cantidad completa") ]
  }
].freeze

CATEGORIES.each_with_index do |data, index|
  category = Category.find_or_initialize_by(slug: data[:slug])
  category.update!(
    name: data[:name], description: data[:description], min_lead_days: data[:min_lead_days], position: index,
    tech_sheet_template: COMMON_FIELDS + data[:fields],
    inspection_template: data[:checks]
  )
end
