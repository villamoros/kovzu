module Portal
  # HU-08: el cliente sigue su pedido. HU-09: revisa la muestra.
  class OrdersController < BaseController
    def index
      @orders = current_company.orders.includes(sub_orders: :milestones).order(created_at: :desc)
    end

    def show
      @order = current_company.orders.includes({ proposals: :quote }, sub_orders: [ :category, :workshop, :milestones, :tech_sheets, :inspections, :payments, { samples: { photos_attachments: :blob } } ])
                              .find_by!(code: params[:id])
    end
  end
end
