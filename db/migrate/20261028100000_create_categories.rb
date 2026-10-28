class CreateCategories < ActiveRecord::Migration[8.0]
  def change
    create_table :categories do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.string :description
      t.integer :min_lead_days, null: false, default: 5
      # [{ "key", "label", "kind" (text|textarea|number|select), "required", "options" }]
      t.jsonb :tech_sheet_template, null: false, default: []
      # [{ "key", "label", "tolerance" }]
      t.jsonb :inspection_template, null: false, default: []
      t.integer :position, null: false, default: 0
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :categories, :slug, unique: true
  end
end
