module Operator
  class DashboardController < BaseController
    inspector_can :show

    def show
      @dashboard = OperatorDashboard.new(params.permit(:workshop_id, :category_id, :client_company_id))
    end
  end
end
