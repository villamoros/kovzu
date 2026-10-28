module Operator
  class RequirementsController < BaseController
    TABS = { "cola" => "En cola", "completo" => "Completos", "no_viable" => "No viables" }.freeze

    before_action :set_requirement, except: %i[index new create]

    def index
      @tab = params[:tab].presence_in(TABS.keys) || "cola"
      scope = Requirement.includes(:client_company, :category, :order)
      @requirements = @tab == "cola" ? scope.in_queue : scope.where(status: @tab).order(submitted_at: :desc).limit(100)
      @counts = Requirement.group(:status).count
    end

    def show
      @categories = Category.active
    end

    # Registrar un requerimiento recibido por WhatsApp o correo (Fase 0).
    def new
      @requirement = Requirement.new(channel: "whatsapp")
    end

    def create
      @requirement = Requirement.new(requirement_params)
      @requirement.client_company = find_or_build_client
      if @requirement.save
        AuditEvent.record!(@requirement, "requerimiento.registrado", actor: actor_name, data: { channel: @requirement.channel })
        redirect_to operator_requirement_path(@requirement), notice: "Requerimiento registrado."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def clarify
      @requirement.ask_clarification!(params[:questions], by: actor_name)
      redirect_to operator_requirement_path(@requirement), notice: "Preguntas guardadas. El requerimiento queda esperando al cliente."
    end

    def answer
      author = params[:answered_by].presence || @requirement.client_company.contact_name.presence || @requirement.client_company.name
      @requirement.record_answer!(params[:answer], by: author)
      redirect_to operator_requirement_path(@requirement), notice: "Respuesta registrada. Vuelve a revisión."
    end

    def complete
      @requirement.update!(category_id: params[:category_id]) if params[:category_id].present?
      @requirement.mark_complete!(by: actor_name)
      redirect_to operator_requirement_path(@requirement), notice: "Requerimiento completo. Ya puedes crear la ficha técnica."
    end

    def reject
      @requirement.mark_not_viable!(params[:reason], by: actor_name)
      redirect_to operator_requirements_path, notice: "Requerimiento cerrado como no viable."
    end

    def start_order
      order = Order.start_from!(@requirement, by: actor_name)
      redirect_to edit_operator_tech_sheet_path(order.sub_orders.first.current_tech_sheet),
                  notice: "Pedido #{order.code} creado. Completa la ficha técnica."
    end

    private

    def set_requirement
      @requirement = Requirement.find(params[:id])
    end

    def requirement_params
      params.expect(requirement: [ :client_company_id, :category_id, :title, :description, :quantity, :dimensions,
                                   :material, :finish, :required_on, :budget_cop, :channel ])
    end

    def find_or_build_client
      name = params.dig(:requirement, :client_company_name).to_s.strip
      return ClientCompany.find_by(id: requirement_params[:client_company_id]) if name.blank?

      ClientCompany.find_or_initialize_by(name:)
    end
  end
end
