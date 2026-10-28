class CreateQuotes < ActiveRecord::Migration[8.0]
  def change
    create_table :quotes do |t|
      t.references :sub_order, null: false, foreign_key: true
      t.references :workshop, null: false, foreign_key: true
      t.references :tech_sheet, null: false, foreign_key: true
      t.string :status, null: false, default: "solicitada"
      t.string :token, null: false
      t.datetime :link_expires_at, null: false
      t.bigint :price_cop
      t.integer :lead_days # días hábiles
      t.text :conditions
      t.date :valid_until
      t.text :decline_reason
      t.boolean :entered_by_operator, null: false, default: false
      t.datetime :submitted_at
      t.timestamps
    end
    add_index :quotes, :token, unique: true
    add_index :quotes, [ :sub_order_id, :workshop_id ], unique: true
  end
end
