class CreateApprovalsAndAuditEvents < ActiveRecord::Migration[8.0]
  def change
    # Registro inmutable de aprobaciones: quién aprobó qué, cuándo y qué versión
    create_table :approvals do |t|
      t.references :approvable, polymorphic: true, null: false
      t.string :decision, null: false # aceptada, rechazada, cambios_solicitados
      t.string :actor_role, null: false # cliente, taller, operador, inspector
      t.string :actor_name, null: false
      t.references :user, foreign_key: true
      t.integer :version
      t.text :comment
      t.datetime :created_at, null: false
    end

    # Bitácora de auditoría por pedido
    create_table :audit_events do |t|
      t.references :subject, polymorphic: true, null: false
      t.references :order, foreign_key: true
      t.string :action, null: false
      t.string :actor_name
      t.jsonb :data, null: false, default: {}
      t.datetime :created_at, null: false
    end
    add_index :audit_events, [ :order_id, :created_at ]
  end
end
