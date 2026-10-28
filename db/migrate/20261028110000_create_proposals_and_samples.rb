class CreateProposalsAndSamples < ActiveRecord::Migration[8.0]
  def change
    # HU-07: propuesta al cliente con la cotización elegida, el fee y la ficha.
    create_table :proposals do |t|
      t.references :order, null: false, foreign_key: true
      t.references :quote, null: false, foreign_key: true
      t.references :tech_sheet, null: false, foreign_key: true
      t.string :status, null: false, default: "enviada"
      t.decimal :workshop_price_cop, precision: 14, scale: 2, null: false
      t.decimal :management_fee_cop, precision: 14, scale: 2, null: false
      t.integer :lead_days, null: false
      t.integer :advance_percent, null: false, default: 50
      t.date :promised_on, null: false
      t.text :terms
      t.text :change_request
      t.string :sent_by
      t.datetime :sent_at
      t.datetime :decided_at
      t.timestamps
    end
    add_index :proposals, :status

    # HU-09: muestra patrón, con fotos y la decisión del cliente.
    create_table :samples do |t|
      t.references :sub_order, null: false, foreign_key: true
      t.integer :number, null: false
      t.string :kind, null: false, default: "fisica"
      t.string :status, null: false, default: "por_revisar"
      t.text :notes
      t.text :comment
      t.string :registered_by
      t.string :decided_by
      t.datetime :decided_at
      t.datetime :reminded_at
      t.timestamps
    end
    add_index :samples, [ :sub_order_id, :number ], unique: true

    add_column :orders, :fee_accrued_at, :datetime
    add_column :requirements, :reference_links, :text
    add_column :quotes, :chosen_at, :datetime
    # RN-13: autorización de tratamiento de datos (Ley 1581 de 2012).
    add_column :users, :data_consent_at, :datetime
  end
end
