class CreateClientCompanies < ActiveRecord::Migration[8.0]
  def change
    create_table :client_companies do |t|
      t.string :name, null: false
      t.string :nit
      t.string :segment # marca, pyme, agencia
      t.string :city, null: false, default: "Cali"
      t.string :contact_name
      t.string :contact_email
      t.string :contact_phone
      t.timestamps
    end
    add_index :client_companies, :nit, unique: true, where: "nit IS NOT NULL"
  end
end
