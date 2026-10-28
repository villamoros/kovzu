module Operator
  # HU-20: cartera de comisiones por taller.
  class CommissionsController < BaseController
    def index
      @portfolio = CommissionPortfolio.new
    end
  end
end
