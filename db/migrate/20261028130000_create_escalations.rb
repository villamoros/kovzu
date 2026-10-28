class CreateEscalations < ActiveRecord::Migration[8.0]
  def change
    # RN-06: lo que decide el operador tras el segundo rechazo del lote.
    create_table :escalations do |t|
      t.references :sub_order, null: false, foreign_key: true
      t.references :workshop, null: false, foreign_key: true
      t.string :decision, null: false
      t.string :status, null: false, default: "aplicada"
      t.text :reason, null: false
      t.string :decided_by
      t.bigint :discount_cop
      t.text :client_comment
      t.string :client_decided_by
      t.datetime :client_decided_at
      t.bigint :refund_cop
      t.date :refund_received_on
      t.boolean :fee_refunded, null: false, default: false
      t.timestamps
    end

    add_column :sub_orders, :discount_cop, :bigint, null: false, default: 0
    add_column :sub_orders, :reassigned_at, :datetime
    # Al reasignar, la nueva propuesta no vuelve a cobrar el fee (RN-07).
    add_column :proposals, :fee_paid_before, :boolean, null: false, default: false
  end
end
