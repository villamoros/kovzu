module Operator
  class TechSheetsController < BaseController
    before_action :set_tech_sheet

    def edit
    end

    def update
      sheet = @tech_sheet.revise!(tech_sheet_params, by: actor_name)
      notice = sheet == @tech_sheet ? "Ficha guardada." : "Se creó la versión #{sheet.version}. Necesita nueva aceptación de cliente y taller."
      redirect_to edit_operator_tech_sheet_path(sheet), notice:
    end

    def ready
      @tech_sheet.mark_ready!(by: actor_name)
      redirect_to new_operator_sub_order_quote_request_path(@tech_sheet.sub_order), notice: "Ficha lista. Elige los talleres que van a cotizar."
    end

    private

    def set_tech_sheet
      @tech_sheet = TechSheet.includes(sub_order: [ :order, :category ]).find(params[:id])
      @sub_order = @tech_sheet.sub_order
      @order = @sub_order.order
    end

    def tech_sheet_params
      keys = @tech_sheet.template_fields.map { |field| field["key"] }
      permitted = params.expect(tech_sheet: [ :acceptance_criteria, { fields: keys } ])
      permitted.to_h.tap { |attrs| attrs["fields"] = attrs.fetch("fields", {}).compact_blank }
    end
  end
end
