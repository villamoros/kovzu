class CreateRequirements < ActiveRecord::Migration[8.0]
  def change
    create_table :requirements do |t|
      t.references :client_company, null: false, foreign_key: true
      t.references :category, foreign_key: true # nulo = "No estoy seguro"
      t.string :title, null: false
      t.text :description
      t.integer :quantity
      t.string :dimensions
      t.string :material
      t.string :finish
      t.date :required_on
      t.bigint :budget_cop
      t.jsonb :details, null: false, default: {}
      t.string :status, null: false, default: "en_revision"
      t.text :rejection_reason
      t.string :channel, null: false, default: "portal" # portal, whatsapp, correo
      t.datetime :submitted_at, null: false
      t.datetime :qualified_at
      t.timestamps
    end
    add_index :requirements, :status

    # Historial de aclaraciones (HU-02): preguntas del operador y respuestas del cliente
    create_table :requirement_messages do |t|
      t.references :requirement, null: false, foreign_key: true
      t.string :author_role, null: false # operador, cliente
      t.string :author_name
      t.text :body, null: false
      t.timestamps
    end
  end
end
