module Operator
  # Registro y verificación de talleres (HU-16).
  class WorkshopsController < BaseController
    before_action :set_workshop, except: %i[index new create]

    def index
      @status = params[:status].presence_in(StatusCatalog.keys(:workshop))
      @category = Category.find_by(id: params[:category_id])
      scope = Workshop.includes(capabilities: :category).ranked
      scope = scope.where(status: @status) if @status
      scope = scope.where(id: WorkshopCapability.where(category: @category).select(:workshop_id)) if @category
      @workshops = scope
      @counts = Workshop.group(:status).count
    end

    def show
      @quotes = @workshop.quotes.includes(sub_order: :order).order(created_at: :desc).limit(10)
      @events = @workshop.audit_events.order(created_at: :desc).limit(10)
    end

    def new
      @workshop = Workshop.new
      @workshop.capabilities.build
    end

    def create
      @workshop = Workshop.new(workshop_params)
      if @workshop.save
        AuditEvent.record!(@workshop, "taller.registrado", actor: actor_name)
        redirect_to operator_workshop_path(@workshop), notice: "Taller registrado como prospecto."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @workshop.capabilities.build
    end

    def update
      if @workshop.update(workshop_params)
        redirect_to operator_workshop_path(@workshop), notice: "Taller actualizado."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def start_verification
      @workshop.start_verification!(by: actor_name)
      redirect_to operator_workshop_path(@workshop), notice: "#{@workshop.name} pasó a verificación."
    end

    def approve_pilot
      @workshop.approve_pilot!(by: actor_name)
      redirect_to operator_workshop_path(@workshop), notice: "#{@workshop.name} quedó verificado y ya puede cotizar."
    end

    def pause
      @workshop.pause!(reason: params[:reason], by: actor_name)
      redirect_to operator_workshop_path(@workshop), notice: "#{@workshop.name} quedó pausado."
    end

    def resume
      @workshop.resume!(by: actor_name)
      redirect_to operator_workshop_path(@workshop), notice: "#{@workshop.name} vuelve a recibir solicitudes."
    end

    def retire
      @workshop.retire!(reason: params[:reason], by: actor_name)
      redirect_to operator_workshop_path(@workshop), notice: "#{@workshop.name} quedó retirado de la red."
    end

    private

    def set_workshop
      @workshop = Workshop.find(params[:id])
    end

    def workshop_params
      params.expect(workshop: [ :name, :nit, :has_rut, :e_invoicing, :contact_name, :phone, :whatsapp, :email, :address,
                                :neighborhood, :machines, :notes, :level, :score, :commission_percent, :payment_details,
                                { visit_checklist: Workshop::VISIT_ITEMS.keys,
                                  capabilities_attributes: [ [ :id, :category_id, :processes, :materials, :min_volume, :max_volume, :tolerances, :_destroy ] ] } ])
    end
  end
end
