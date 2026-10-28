require "csv"

module Operator
  # HU-20 / CU-13: el corte mensual genera el detalle por taller para facturar, y luego se registra el pago.
  class CommissionCutsController < BaseController
    before_action :set_cut, only: %i[show invoice pay]

    def show
      respond_to do |format|
        format.html
        format.csv { send_data cut_csv, filename: "comisiones-#{@cut.to_param}.csv", type: "text/csv" }
      end
    end

    def create
      cut = CommissionCut.run!(month: Date.strptime(params[:month].to_s, "%Y-%m"), by: actor_name)
      redirect_to operator_commission_cut_path(cut), notice: "Corte de #{cut.name.downcase} generado."
    rescue Date::Error
      redirect_to operator_commissions_path, alert: "Elige el mes del corte."
    end

    def invoice
      @cut.invoice!(workshop, number: params[:invoice_number], invoiced_on: params[:invoiced_on], due_on: params[:due_on], by: actor_name)
      redirect_to operator_commission_cut_path(@cut), notice: "Factura de #{workshop.name} registrada."
    end

    def pay
      @cut.mark_paid!(workshop, paid_on: params[:paid_on], by: actor_name)
      redirect_to operator_commission_cut_path(@cut), notice: "Pago de #{workshop.name} registrado."
    end

    private

    def set_cut
      @cut = CommissionCut.find_by!(period_start: Date.strptime(params[:id].to_s, "%Y-%m"))
    rescue Date::Error
      raise ActiveRecord::RecordNotFound
    end

    def workshop = @workshop ||= Workshop.find(params[:workshop_id])

    def cut_csv
      CSV.generate(col_sep: ";") do |csv|
        csv << [ "Taller", "NIT", "Pedido", "Subpedido", "Saldo pagado", "Base antes de IVA", "Porcentaje", "Comisión", "Estado", "Factura" ]
        @cut.by_workshop.each do |shop, commissions|
          commissions.each do |commission|
            csv << [ shop.name, shop.nit, commission.order.code, commission.sub_order.title, commission.accrued_on, commission.base_cop,
                     commission.percent.to_s("F"), commission.amount_cop, commission.status_label, commission.invoice_number ]
          end
        end
      end
    end
  end
end
