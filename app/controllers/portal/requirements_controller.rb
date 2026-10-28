module Portal
  # HU-01: requerimiento guiado por categoría. HU-02: el cliente responde las aclaraciones.
  class RequirementsController < BaseController
    before_action :set_requirement, only: %i[show answer]

    def index
      @requirements = current_company.requirements.includes(:category, :order).order(submitted_at: :desc)
    end

    def new
      @categories = Category.active
      return render :categories unless params.key?(:categoria)

      @requirement = current_company.requirements.build(category: Category.active.find_by(slug: params[:categoria]))
    end

    def create
      @requirement = current_company.requirements.build(requirement_params)
      @requirement.submit_from_portal!(by: current_user.name)
      redirect_to requirement_path(@requirement), notice: "Enviado. Te avisamos por correo cuando lo revisemos."
    rescue ActiveRecord::RecordInvalid
      render :new, status: :unprocessable_entity
    end

    def show
    end

    def answer
      @requirement.record_answer!(params[:answer], by: current_user.name, role: "cliente")
      redirect_to requirement_path(@requirement), notice: "Gracias. Tu respuesta volvió a revisión."
    end

    private

    def set_requirement
      @requirement = current_company.requirements.find(params[:id])
    end

    def requirement_params
      category = Category.active.find_by(id: params.dig(:requirement, :category_id))
      detail_keys = category ? category.tech_sheet_fields.map { |field| field["key"] } - Category::REQUIREMENT_FIELDS.keys : []
      params.expect(requirement: [ :category_id, :title, :quantity, :dimensions, :material, :finish, :required_on, :budget_cop,
                                   :description, :reference_links, { files: [], details: detail_keys } ])
    end
  end
end
