class AddKovzuRoleToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :role, :string, null: false, default: "cliente" # cliente, operador, inspector, admin
    add_reference :users, :client_company, foreign_key: true
  end
end
