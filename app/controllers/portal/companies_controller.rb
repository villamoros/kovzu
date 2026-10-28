module Portal
  # Alta del cliente: la primera vez que entra registra su empresa y autoriza el uso de datos (RN-13).
  class CompaniesController < BaseController
    skip_before_action :require_client_company!
    before_action :redirect_staff_and_registered

    def new
      @company = ClientCompany.new(contact_name: current_user.name, contact_email: current_user.email)
    end

    def create
      @company = ClientCompany.new(company_params)
      unless params[:data_consent] == "1"
        @company.validate
        @company.errors.add(:base, "Necesitamos tu autorización para tratar tus datos")
        return render :new, status: :unprocessable_entity
      end

      ClientCompany.transaction do
        @company.save!
        current_user.update!(client_company: @company, data_consent_at: Time.current)
      end
      redirect_to new_requirement_path, notice: "Listo, #{@company.name} quedó registrada. Cuéntanos qué necesitas fabricar."
    rescue ActiveRecord::RecordInvalid
      render :new, status: :unprocessable_entity
    end

    private

    def redirect_staff_and_registered
      return redirect_to operator_root_path if current_user.staff?

      redirect_to dashboard_path if current_company
    end

    def company_params
      params.expect(client_company: %i[name nit segment city contact_name contact_email contact_phone])
    end
  end
end
