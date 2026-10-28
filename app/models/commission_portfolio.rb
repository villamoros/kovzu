# Cartera de comisiones por taller (HU-20): causado, facturado, en mora y pagado, con totales.
class CommissionPortfolio
  BUCKETS = { causada: "Causado", facturada: "Facturado", en_mora: "En mora", pagada: "Pagado" }.freeze
  Row = Data.define(:workshop, :amounts, :commissions) do
    def total = amounts.values.sum
    def delinquent? = amounts[:en_mora].positive?
    def max_days_overdue = commissions.map(&:days_overdue).max.to_i
  end

  def commissions
    @commissions ||= Commission.active.includes(:workshop, :commission_cut, sub_order: :order).order(:accrued_on).to_a
  end

  def rows
    @rows ||= commissions.group_by(&:workshop).map do |workshop, list|
      amounts = BUCKETS.keys.index_with { |bucket| list.select { |commission| commission.bucket == bucket }.sum(&:amount_cop) }
      Row.new(workshop:, amounts:, commissions: list)
    end.sort_by { |row| [ row.delinquent? ? 0 : 1, -row.total ] }
  end

  def totals = BUCKETS.keys.index_with { |bucket| rows.sum { |row| row.amounts[bucket] } }

  def delinquent_rows = rows.select(&:delinquent?)

  def uncut = Commission.uncut

  def cuts = CommissionCut.order(period_start: :desc).includes(:commissions)
end
