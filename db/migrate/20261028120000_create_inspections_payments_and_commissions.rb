class CreateInspectionsPaymentsAndCommissions < ActiveRecord::Migration[8.0]
  def change
    # HU-05: el taller pide un enlace nuevo cuando el suyo venció.
    add_column :quotes, :renewal_requested_at, :datetime

    # RN-08: porcentaje de comisión del convenio (8–12 %). Datos de pago para el aviso del saldo (HU-13).
    add_column :workshops, :commission_percent, :decimal, precision: 4, scale: 2, null: false, default: 10
    add_column :workshops, :payment_details, :text

    # HU-12 / HU-13: inspección del lote, inmutable al cerrarse.
    create_table :inspections do |t|
      t.references :sub_order, null: false, foreign_key: true
      t.integer :number, null: false
      t.references :reinspection_of, foreign_key: { to_table: :inspections }
      t.string :status, null: false, default: "abierta"
      t.string :result
      t.integer :lot_size
      t.integer :sample_size
      t.integer :tech_sheet_version
      t.text :criteria
      t.text :notes
      t.date :rework_due_on
      t.string :started_by
      t.string :closed_by
      t.references :closed_by_user, foreign_key: { to_table: :users }
      t.datetime :closed_at
      t.string :deviation_status
      t.text :deviation_comment
      t.string :deviation_decided_by
      t.datetime :deviation_decided_at
      t.datetime :report_sent_at
      t.timestamps
    end
    add_index :inspections, %i[sub_order_id number], unique: true

    create_table :inspection_items do |t|
      t.references :inspection, null: false, foreign_key: true
      t.integer :position, null: false, default: 0
      t.string :key, null: false
      t.string :label, null: false
      t.string :tolerance
      t.string :result
      t.string :measurement
      t.string :severity
      t.text :note
      t.timestamps
    end

    # HU-19: anticipo y saldo que el cliente paga al taller, con soporte. Se anulan, no se borran.
    create_table :payments do |t|
      t.references :sub_order, null: false, foreign_key: true
      t.string :kind, null: false
      t.bigint :amount_cop, null: false
      t.bigint :expected_cop
      t.date :paid_on, null: false
      t.string :status, null: false, default: "vigente"
      t.text :notes
      t.string :registered_by
      t.text :void_reason
      t.string :voided_by
      t.datetime :voided_at
      t.timestamps
    end
    add_index :payments, %i[sub_order_id kind status]

    # HU-20: corte mensual y cartera de comisiones por taller.
    create_table :commission_cuts do |t|
      t.date :period_start, null: false
      t.date :period_end, null: false
      t.string :generated_by
      t.timestamps
    end
    add_index :commission_cuts, :period_start, unique: true

    create_table :commissions do |t|
      t.references :workshop, null: false, foreign_key: true
      t.references :sub_order, null: false, foreign_key: true
      t.references :payment, foreign_key: true
      t.references :commission_cut, foreign_key: true
      t.bigint :base_cop, null: false
      t.decimal :percent, precision: 4, scale: 2, null: false
      t.bigint :amount_cop, null: false
      t.string :status, null: false, default: "causada"
      t.date :accrued_on, null: false
      t.string :invoice_number
      t.date :invoiced_on
      t.date :due_on
      t.date :paid_on
      t.text :void_reason
      t.timestamps
    end
    add_index :commissions, :status
  end
end
