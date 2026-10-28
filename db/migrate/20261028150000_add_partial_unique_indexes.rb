# Reglas de unicidad que antes solo vivían en Ruby. Con dos peticiones a la vez, la base de datos rechaza la segunda.
class AddPartialUniqueIndexes < ActiveRecord::Migration[8.0]
  def change
    add_index :payments, %i[sub_order_id kind], unique: true, where: "status = 'vigente'", name: "index_payments_one_active_per_kind"
    add_index :commissions, :sub_order_id, unique: true, where: "status <> 'anulada'", name: "index_commissions_one_active_per_sub_order"
    add_index :escalations, :sub_order_id, unique: true, where: "status = 'esperando_cliente'", name: "index_escalations_one_pending_discount"
  end
end
