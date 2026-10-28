module Operator
  class OrdersController < BaseController
    inspector_can :show

    def show
      @order = Order.includes(:client_company, :requirement, proposals: { quote: :workshop },
                                  sub_orders: [ :category, :workshop, :milestones, :tech_sheets, :inspections, { escalations: :workshop }, { payments: :support_attachment, quotes: [ :workshop, :tech_sheet, :approvals, :support_attachment ], samples: :photos_attachments } ])
                    .find_by!(code: params[:id])
      @events = @order.audit_events.limit(20)
    end
  end
end
