module Operator
  # HU-12: inspección desde el celular. Se guarda el avance y se cierra con el resultado; cerrada no cambia.
  class InspectionsController < BaseController
    before_action :set_inspection, only: %i[show progress close]

    def create
      sub_order = SubOrder.find(params[:sub_order_id])
      inspection = Inspection.start_for!(sub_order, by: actor_name)
      redirect_to operator_inspection_path(inspection)
    end

    def show
    end

    def progress
      save_progress!
      redirect_to operator_inspection_path(@inspection), notice: "Avance guardado."
    end

    def close
      save_progress!
      @inspection.close!(result: params[:result], rework_due_on: params[:rework_due_on].presence, user: current_user)
      redirect_to operator_inspection_path(@inspection), notice: "Inspección cerrada. El acta se envía al cliente y al taller."
    rescue Inspection::TransitionError => error
      flash.now[:alert] = error.message
      @inspection.reload
      render :show, status: :unprocessable_entity
    end

    private

    def set_inspection
      @inspection = Inspection.includes(items: { photos_attachments: :blob }, sub_order: [ :order, :category, :workshop, :tech_sheets ]).find(params[:id])
    end

    def save_progress!
      ids = @inspection.items.map { |item| item.id.to_s }
      items = params.fetch(:items, {}).permit(ids.index_with { %i[result measurement severity note] }).to_h
      photos = params.fetch(:photos, {}).permit(ids.index_with { [] }).to_h
      @inspection.record!(items, notes: params[:notes], photos:)
    end
  end
end
