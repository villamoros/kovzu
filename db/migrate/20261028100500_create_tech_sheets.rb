class CreateTechSheets < ActiveRecord::Migration[8.0]
  def change
    create_table :tech_sheets do |t|
      t.references :sub_order, null: false, foreign_key: true
      t.integer :version, null: false, default: 1
      t.string :status, null: false, default: "borrador" # borrador, lista, aceptada, reemplazada
      t.jsonb :fields, null: false, default: {}
      t.text :acceptance_criteria
      t.datetime :accepted_by_client_at
      t.datetime :accepted_by_workshop_at
      t.timestamps
    end
    add_index :tech_sheets, [ :sub_order_id, :version ], unique: true
  end
end
