module Operator
  class DashboardController < BaseController
    def show
      @dashboard = OperatorDashboard.new(params.permit(:workshop_id, :category_id, :client_company_id))
    end
  end
end
