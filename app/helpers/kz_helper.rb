# Helpers del sistema de diseño KOVZU: logo, iconos de capacidad y estados.
# Las clases CSS están en app/assets/tailwind/kovzu/components.css.
module KzHelper
  CAPABILITIES = {
    "corte"         => "Corte y conformado",
    "impresion"     => "Impresión y etiquetas",
    "empaques"      => "Empaques",
    "confeccion"    => "Confección y bordado",
    "carpinteria"   => "Carpintería",
    "metalmecanica" => "Metalmecánica liviana"
  }.freeze

  # Glifos de interfaz (24 px, trazo 1.75). Los iconos de marca son los de capacidad.
  GLYPHS = {
    check: '<circle cx="12" cy="12" r="9"/><path d="M8 12.5l2.5 2.5L16 9.5"/>',
    alert: '<path d="M12 3.5l9 16H3z"/><path d="M12 10v4M12 17v.01"/>',
    info: '<circle cx="12" cy="12" r="9"/><path d="M12 11v5M12 8v.01"/>',
    close: '<path d="M6 6l12 12M18 6L6 18"/>',
    moon: '<path d="M20 14.5A8 8 0 1 1 9.5 4a6.5 6.5 0 0 0 10.5 10.5z"/>',
    sun: '<circle cx="12" cy="12" r="4"/><path d="M12 2.5v2M12 19.5v2M2.5 12h2M19.5 12h2M5.3 5.3l1.4 1.4M17.3 17.3l1.4 1.4M5.3 18.7l1.4-1.4M17.3 6.7l1.4-1.4"/>',
    plus: '<path d="M12 5v14M5 12h14"/>',
    arrow: '<path d="M5 12h14M13 6l6 6-6 6"/>'
  }.freeze

  MONTHS = %w[ene feb mar abr may jun jul ago sep oct nov dic].freeze

  BRAND_INK = 'fill="#0B1F33"'.freeze
  ICON_INK = 'stroke="#0B1F33"'.freeze

  # <%= kz_glyph :check %>
  def kz_glyph(name, size: 16, **options)
    tag.svg(GLYPHS.fetch(name.to_sym).html_safe, # rubocop:disable Rails/OutputSafety -- constante propia
            xmlns: "http://www.w3.org/2000/svg", viewBox: "0 0 24 24", width: size, height: size,
            fill: "none", stroke: "currentColor", "stroke-width": 1.75, "stroke-linecap": "round", "stroke-linejoin": "round",
            class: [ "kz-icon", options[:class] ], aria: { hidden: true }, focusable: false)
  end

  # Fecha corta en español: "21 oct". Acepta Date, Time o texto.
  def kz_date(value)
    return value if value.blank? || value.is_a?(String)

    "#{value.day} #{MONTHS[value.month - 1]}"
  end

  # <%= kz_status order.status %>
  # <%= kz_status sub_order.status, kind: :sub_order %>
  # Tipos: :order, :sub_order, :requirement, :tech_sheet, :quote, :proposal, :sample, :workshop (ver StatusCatalog).
  def kz_status(key, kind: :order, label: nil)
    status = StatusCatalog.fetch(kind, key)
    tone_class = "kz-status--#{status[:tone]}" unless status[:tone] == :neutral
    tag.span(label || status[:label], class: [ "kz-status", tone_class ])
  end

  # Pesos colombianos: "$ 1.250.000"
  def kz_money(value)
    return "—" if value.nil?

    number_to_currency(value, unit: "$ ", delimiter: ".", separator: ",", precision: 0, format: "%u%n")
  end

  # <%= kz_logo %>                       símbolo + KOVZU
  # <%= kz_logo :symbol, class: "h-8" %> solo la K
  # <%= kz_logo :signature %>            con "Red de manufactura verificada"
  # Toma el color del texto (currentColor); el acento lima no cambia.
  def kz_logo(variant = :lockup, **options)
    inline_svg("kovzu-#{variant}.svg", BRAND_INK, 'fill="currentColor"', class: [ "kz-logo", options[:class] ])
  end

  # <%= kz_icon "empaques" %> · <%= kz_icon "corte", size: 40 %>
  def kz_icon(name, size: 20, **options)
    inline_svg("icons/kz-#{name}.svg", ICON_INK, 'stroke="currentColor"',
               class: [ "kz-icon", options[:class] ], width: size, height: size, decorative: options.fetch(:decorative, true))
  end

  # <%= kz_capability "empaques" %>
  def kz_capability(name)
    tag.span(class: "kz-cap") { safe_join([ kz_icon(name), CAPABILITIES.fetch(name.to_s, name.to_s.humanize) ]) }
  end

  private

  def inline_svg(file, from, to, **attrs)
    source = KzHelper.svg_source(file).sub("<svg ", "<svg #{svg_attributes(attrs)} ").gsub(from, to)
    source = source.sub(/role="img" aria-label="[^"]*"/, 'aria-hidden="true" focusable="false"').sub(%r{<title>.*?</title>}, "") if attrs[:decorative]
    source.html_safe # rubocop:disable Rails/OutputSafety -- archivo propio del repo
  end

  def svg_attributes(attrs)
    attrs.except(:decorative).filter_map do |key, value|
      value = Array(value).compact.join(" ")
      %(#{key}="#{ERB::Util.html_escape(value)}") if value.present?
    end.join(" ")
  end

  def self.svg_source(file)
    @svg_sources ||= {}
    return @svg_sources[file] if @svg_sources.key?(file) && !Rails.env.development?

    @svg_sources[file] = Rails.root.join("app/assets/images/kovzu", file).read
  end
end
