class CreateOrders < ActiveRecord::Migration[8.0]
  def change
    create_table :orders do |t|
      t.string :code, null: false
      t.references :client_company, null: false, foreign_key: true
      t.references :requirement, foreign_key: true
      t.string :status, null: false, default: "en_revision"
      t.string :kind, null: false, default: "simple" # simple, multi_taller, inspeccion_planta
      t.bigint :management_fee_cop
      t.date :promised_on
      t.datetime :confirmed_at
      t.datetime :delivered_at
      t.timestamps
    end
    add_index :orders, :code, unique: true
    add_index :orders, :status

    create_table :sub_orders do |t|
      t.references :order, null: false, foreign_key: true
      t.references :category, null: false, foreign_key: true
      t.references :workshop, foreign_key: true
      t.string :title, null: false
      t.integer :quantity
      t.string :status, null: false, default: "en_revision"
      t.bigint :amount_cop
      t.integer :rejection_count, null: false, default: 0
      t.timestamps
    end
    add_index :sub_orders, :status
  end
end
