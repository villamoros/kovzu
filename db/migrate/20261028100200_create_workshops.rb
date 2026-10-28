class CreateWorkshops < ActiveRecord::Migration[8.0]
  def change
    create_table :workshops do |t|
      t.string :name, null: false
      t.string :nit
      t.boolean :has_rut, null: false, default: false
      t.boolean :e_invoicing, null: false, default: false
      t.string :status, null: false, default: "prospecto"
      t.string :level # verificado, confiable, preferente
      t.decimal :score, precision: 4, scale: 1
      t.string :contact_name
      t.string :phone
      t.string :whatsapp
      t.string :email
      t.string :address
      t.string :neighborhood
      t.text :machines
      t.text :notes
      # { "rut" => true, "facturacion_electronica" => true, "maquinas" => true, "fotos" => true, "visita" => true }
      t.jsonb :visit_checklist, null: false, default: {}
      t.datetime :visited_at
      t.datetime :pilot_approved_at
      t.string :status_reason
      t.timestamps
    end
    add_index :workshops, :status
    add_index :workshops, :nit, unique: true, where: "nit IS NOT NULL"

    create_table :workshop_capabilities do |t|
      t.references :workshop, null: false, foreign_key: true
      t.references :category, null: false, foreign_key: true
      t.string :processes
      t.string :materials
      t.integer :min_volume
      t.integer :max_volume
      t.string :tolerances
      t.timestamps
    end
    add_index :workshop_capabilities, [ :workshop_id, :category_id ], unique: true
  end
end
