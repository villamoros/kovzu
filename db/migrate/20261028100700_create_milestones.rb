class CreateMilestones < ActiveRecord::Migration[8.0]
  def change
    create_table :milestones do |t|
      t.references :sub_order, null: false, foreign_key: true
      t.string :kind, null: false # anticipo, muestra, produccion, inspeccion, despacho, entrega
      t.string :title, null: false
      t.integer :position, null: false, default: 0
      t.date :committed_on
      t.date :original_committed_on
      t.date :completed_on
      t.string :reschedule_reason
      t.string :rescheduled_by # taller, cliente, kovzu
      t.timestamps
    end
    add_index :milestones, [ :sub_order_id, :position ]
  end
end
