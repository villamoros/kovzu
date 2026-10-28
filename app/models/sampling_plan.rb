# Tamaño de muestra según el lote (RF-18, P0): tabla fija tomada de ISO 2859-1, nivel general II.
# El cálculo por nivel de inspección queda para P1.
module SamplingPlan
  # [lote hasta, unidades a revisar]
  TABLE = [
    [ 8, 2 ], [ 15, 3 ], [ 25, 5 ], [ 50, 8 ], [ 90, 13 ], [ 150, 20 ], [ 280, 32 ], [ 500, 50 ],
    [ 1_200, 80 ], [ 3_200, 125 ], [ 10_000, 200 ], [ 35_000, 315 ], [ 150_000, 500 ], [ 500_000, 800 ]
  ].freeze
  LARGEST = 1_250

  def self.sample_size(lot_size)
    lot = lot_size.to_i
    return 0 unless lot.positive?

    [ TABLE.find { |limit, _| lot <= limit }&.last || LARGEST, lot ].min
  end

  # Rango del lote que corresponde a la fila, para mostrarlo en el acta.
  def self.range_label(lot_size)
    lot = lot_size.to_i
    index = TABLE.index { |limit, _| lot <= limit }
    return "más de #{delimited(TABLE.last.first)}" unless index

    from = index.zero? ? 2 : TABLE[index - 1].first + 1
    "#{delimited(from)}–#{delimited(TABLE[index].first)}"
  end

  def self.delimited(number) = ActiveSupport::NumberHelper.number_to_delimited(number, delimiter: ".")
end
