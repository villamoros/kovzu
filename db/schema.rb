# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2026_10_28_150000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "approvals", force: :cascade do |t|
    t.string "approvable_type", null: false
    t.bigint "approvable_id", null: false
    t.string "decision", null: false
    t.string "actor_role", null: false
    t.string "actor_name", null: false
    t.bigint "user_id"
    t.integer "version"
    t.text "comment"
    t.datetime "created_at", null: false
    t.index ["approvable_type", "approvable_id"], name: "index_approvals_on_approvable"
    t.index ["user_id"], name: "index_approvals_on_user_id"
  end

  create_table "audit_events", force: :cascade do |t|
    t.string "subject_type", null: false
    t.bigint "subject_id", null: false
    t.bigint "order_id"
    t.string "action", null: false
    t.string "actor_name"
    t.jsonb "data", default: {}, null: false
    t.datetime "created_at", null: false
    t.index ["order_id", "created_at"], name: "index_audit_events_on_order_id_and_created_at"
    t.index ["order_id"], name: "index_audit_events_on_order_id"
    t.index ["subject_type", "subject_id"], name: "index_audit_events_on_subject"
  end

  create_table "categories", force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.string "description"
    t.integer "min_lead_days", default: 5, null: false
    t.jsonb "tech_sheet_template", default: [], null: false
    t.jsonb "inspection_template", default: [], null: false
    t.integer "position", default: 0, null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_categories_on_slug", unique: true
  end

  create_table "client_companies", force: :cascade do |t|
    t.string "name", null: false
    t.string "nit"
    t.string "segment"
    t.string "city", default: "Cali", null: false
    t.string "contact_name"
    t.string "contact_email"
    t.string "contact_phone"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["nit"], name: "index_client_companies_on_nit", unique: true, where: "(nit IS NOT NULL)"
  end

  create_table "commission_cuts", force: :cascade do |t|
    t.date "period_start", null: false
    t.date "period_end", null: false
    t.string "generated_by"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["period_start"], name: "index_commission_cuts_on_period_start", unique: true
  end

  create_table "commissions", force: :cascade do |t|
    t.bigint "workshop_id", null: false
    t.bigint "sub_order_id", null: false
    t.bigint "payment_id"
    t.bigint "commission_cut_id"
    t.bigint "base_cop", null: false
    t.decimal "percent", precision: 4, scale: 2, null: false
    t.bigint "amount_cop", null: false
    t.string "status", default: "causada", null: false
    t.date "accrued_on", null: false
    t.string "invoice_number"
    t.date "invoiced_on"
    t.date "due_on"
    t.date "paid_on"
    t.text "void_reason"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["commission_cut_id"], name: "index_commissions_on_commission_cut_id"
    t.index ["payment_id"], name: "index_commissions_on_payment_id"
    t.index ["status"], name: "index_commissions_on_status"
    t.index ["sub_order_id"], name: "index_commissions_on_sub_order_id"
    t.index ["sub_order_id"], name: "index_commissions_one_active_per_sub_order", unique: true, where: "((status)::text <> 'anulada'::text)"
    t.index ["workshop_id"], name: "index_commissions_on_workshop_id"
  end

  create_table "escalations", force: :cascade do |t|
    t.bigint "sub_order_id", null: false
    t.bigint "workshop_id", null: false
    t.string "decision", null: false
    t.string "status", default: "aplicada", null: false
    t.text "reason", null: false
    t.string "decided_by"
    t.bigint "discount_cop"
    t.text "client_comment"
    t.string "client_decided_by"
    t.datetime "client_decided_at"
    t.bigint "refund_cop"
    t.date "refund_received_on"
    t.boolean "fee_refunded", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["sub_order_id"], name: "index_escalations_on_sub_order_id"
    t.index ["sub_order_id"], name: "index_escalations_one_pending_discount", unique: true, where: "((status)::text = 'esperando_cliente'::text)"
    t.index ["workshop_id"], name: "index_escalations_on_workshop_id"
  end

  create_table "inspection_items", force: :cascade do |t|
    t.bigint "inspection_id", null: false
    t.integer "position", default: 0, null: false
    t.string "key", null: false
    t.string "label", null: false
    t.string "tolerance"
    t.string "result"
    t.string "measurement"
    t.string "severity"
    t.text "note"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["inspection_id"], name: "index_inspection_items_on_inspection_id"
  end

  create_table "inspections", force: :cascade do |t|
    t.bigint "sub_order_id", null: false
    t.integer "number", null: false
    t.bigint "reinspection_of_id"
    t.string "status", default: "abierta", null: false
    t.string "result"
    t.integer "lot_size"
    t.integer "sample_size"
    t.integer "tech_sheet_version"
    t.text "criteria"
    t.text "notes"
    t.date "rework_due_on"
    t.string "started_by"
    t.string "closed_by"
    t.bigint "closed_by_user_id"
    t.datetime "closed_at"
    t.string "deviation_status"
    t.text "deviation_comment"
    t.string "deviation_decided_by"
    t.datetime "deviation_decided_at"
    t.datetime "report_sent_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "client_report_sent_at"
    t.datetime "workshop_report_sent_at"
    t.index ["closed_by_user_id"], name: "index_inspections_on_closed_by_user_id"
    t.index ["reinspection_of_id"], name: "index_inspections_on_reinspection_of_id"
    t.index ["sub_order_id", "number"], name: "index_inspections_on_sub_order_id_and_number", unique: true
    t.index ["sub_order_id"], name: "index_inspections_on_sub_order_id"
  end

  create_table "milestones", force: :cascade do |t|
    t.bigint "sub_order_id", null: false
    t.string "kind", null: false
    t.string "title", null: false
    t.integer "position", default: 0, null: false
    t.date "committed_on"
    t.date "original_committed_on"
    t.date "completed_on"
    t.string "reschedule_reason"
    t.string "rescheduled_by"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["sub_order_id", "position"], name: "index_milestones_on_sub_order_id_and_position"
    t.index ["sub_order_id"], name: "index_milestones_on_sub_order_id"
  end

  create_table "orders", force: :cascade do |t|
    t.string "code", null: false
    t.bigint "client_company_id", null: false
    t.bigint "requirement_id"
    t.string "status", default: "en_revision", null: false
    t.string "kind", default: "simple", null: false
    t.bigint "management_fee_cop"
    t.date "promised_on"
    t.datetime "confirmed_at"
    t.datetime "delivered_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "fee_accrued_at"
    t.index ["client_company_id"], name: "index_orders_on_client_company_id"
    t.index ["code"], name: "index_orders_on_code", unique: true
    t.index ["requirement_id"], name: "index_orders_on_requirement_id"
    t.index ["status"], name: "index_orders_on_status"
  end

  create_table "payments", force: :cascade do |t|
    t.bigint "sub_order_id", null: false
    t.string "kind", null: false
    t.bigint "amount_cop", null: false
    t.bigint "expected_cop"
    t.date "paid_on", null: false
    t.string "status", default: "vigente", null: false
    t.text "notes"
    t.string "registered_by"
    t.text "void_reason"
    t.string "voided_by"
    t.datetime "voided_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["sub_order_id", "kind", "status"], name: "index_payments_on_sub_order_id_and_kind_and_status"
    t.index ["sub_order_id", "kind"], name: "index_payments_one_active_per_kind", unique: true, where: "((status)::text = 'vigente'::text)"
    t.index ["sub_order_id"], name: "index_payments_on_sub_order_id"
  end

  create_table "proposals", force: :cascade do |t|
    t.bigint "order_id", null: false
    t.bigint "quote_id", null: false
    t.bigint "tech_sheet_id", null: false
    t.string "status", default: "enviada", null: false
    t.decimal "workshop_price_cop", precision: 14, scale: 2, null: false
    t.decimal "management_fee_cop", precision: 14, scale: 2, null: false
    t.integer "lead_days", null: false
    t.integer "advance_percent", default: 50, null: false
    t.date "promised_on", null: false
    t.text "terms"
    t.text "change_request"
    t.string "sent_by"
    t.datetime "sent_at"
    t.datetime "decided_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "fee_paid_before", default: false, null: false
    t.index ["order_id"], name: "index_proposals_on_order_id"
    t.index ["quote_id"], name: "index_proposals_on_quote_id"
    t.index ["status"], name: "index_proposals_on_status"
    t.index ["tech_sheet_id"], name: "index_proposals_on_tech_sheet_id"
  end

  create_table "quotes", force: :cascade do |t|
    t.bigint "sub_order_id", null: false
    t.bigint "workshop_id", null: false
    t.bigint "tech_sheet_id", null: false
    t.string "status", default: "solicitada", null: false
    t.string "token", null: false
    t.datetime "link_expires_at", null: false
    t.bigint "price_cop"
    t.integer "lead_days"
    t.text "conditions"
    t.date "valid_until"
    t.text "decline_reason"
    t.boolean "entered_by_operator", default: false, null: false
    t.datetime "submitted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "chosen_at"
    t.datetime "renewal_requested_at"
    t.index ["sub_order_id", "workshop_id"], name: "index_quotes_on_sub_order_id_and_workshop_id", unique: true
    t.index ["sub_order_id"], name: "index_quotes_on_sub_order_id"
    t.index ["tech_sheet_id"], name: "index_quotes_on_tech_sheet_id"
    t.index ["token"], name: "index_quotes_on_token", unique: true
    t.index ["workshop_id"], name: "index_quotes_on_workshop_id"
  end

  create_table "requirement_messages", force: :cascade do |t|
    t.bigint "requirement_id", null: false
    t.string "author_role", null: false
    t.string "author_name"
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["requirement_id"], name: "index_requirement_messages_on_requirement_id"
  end

  create_table "requirements", force: :cascade do |t|
    t.bigint "client_company_id", null: false
    t.bigint "category_id"
    t.string "title", null: false
    t.text "description"
    t.integer "quantity"
    t.string "dimensions"
    t.string "material"
    t.string "finish"
    t.date "required_on"
    t.bigint "budget_cop"
    t.jsonb "details", default: {}, null: false
    t.string "status", default: "en_revision", null: false
    t.text "rejection_reason"
    t.string "channel", default: "portal", null: false
    t.datetime "submitted_at", null: false
    t.datetime "qualified_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "reference_links"
    t.index ["category_id"], name: "index_requirements_on_category_id"
    t.index ["client_company_id"], name: "index_requirements_on_client_company_id"
    t.index ["status"], name: "index_requirements_on_status"
  end

  create_table "samples", force: :cascade do |t|
    t.bigint "sub_order_id", null: false
    t.integer "number", null: false
    t.string "kind", default: "fisica", null: false
    t.string "status", default: "por_revisar", null: false
    t.text "notes"
    t.text "comment"
    t.string "registered_by"
    t.string "decided_by"
    t.datetime "decided_at"
    t.datetime "reminded_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["sub_order_id", "number"], name: "index_samples_on_sub_order_id_and_number", unique: true
    t.index ["sub_order_id"], name: "index_samples_on_sub_order_id"
  end

  create_table "solid_queue_batch_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.bigint "batch_id", null: false
    t.datetime "created_at", null: false
    t.index ["batch_id"], name: "index_solid_queue_batch_executions_on_batch_id"
    t.index ["job_id"], name: "index_solid_queue_batch_executions_on_job_id", unique: true
  end

  create_table "solid_queue_batches", force: :cascade do |t|
    t.string "active_job_batch_id"
    t.string "description"
    t.text "on_finish"
    t.text "on_success"
    t.text "on_failure"
    t.text "metadata"
    t.integer "total_jobs", default: 0, null: false
    t.integer "completed_jobs", default: 0, null: false
    t.integer "failed_jobs", default: 0, null: false
    t.datetime "enqueued_at"
    t.datetime "finished_at"
    t.datetime "failed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active_job_batch_id"], name: "index_solid_queue_batches_on_active_job_batch_id", unique: true
    t.index ["finished_at"], name: "index_solid_queue_batches_on_finished_at"
  end

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.string "concurrency_key", null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.text "error"
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "queue_name", null: false
    t.string "class_name", null: false
    t.text "arguments"
    t.integer "priority", default: 0, null: false
    t.string "active_job_id"
    t.datetime "scheduled_at"
    t.datetime "finished_at"
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "batch_id"
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["batch_id"], name: "index_solid_queue_jobs_on_batch_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.string "queue_name", null: false
    t.datetime "created_at", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.bigint "supervisor_id"
    t.integer "pid", null: false
    t.string "hostname"
    t.text "metadata"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "task_key", null: false
    t.datetime "run_at", null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.string "key", null: false
    t.string "schedule", null: false
    t.string "command", limit: 2048
    t.string "class_name"
    t.text "arguments"
    t.string "queue_name"
    t.integer "priority", default: 0
    t.boolean "static", default: true, null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "scheduled_at", null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.string "key", null: false
    t.integer "value", default: 1, null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
  end

  create_table "sub_orders", force: :cascade do |t|
    t.bigint "order_id", null: false
    t.bigint "category_id", null: false
    t.bigint "workshop_id"
    t.string "title", null: false
    t.integer "quantity"
    t.string "status", default: "en_revision", null: false
    t.bigint "amount_cop"
    t.integer "rejection_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "discount_cop", default: 0, null: false
    t.datetime "reassigned_at"
    t.index ["category_id"], name: "index_sub_orders_on_category_id"
    t.index ["order_id"], name: "index_sub_orders_on_order_id"
    t.index ["status"], name: "index_sub_orders_on_status"
    t.index ["workshop_id"], name: "index_sub_orders_on_workshop_id"
  end

  create_table "tech_sheets", force: :cascade do |t|
    t.bigint "sub_order_id", null: false
    t.integer "version", default: 1, null: false
    t.string "status", default: "borrador", null: false
    t.jsonb "fields", default: {}, null: false
    t.text "acceptance_criteria"
    t.datetime "accepted_by_client_at"
    t.datetime "accepted_by_workshop_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["sub_order_id", "version"], name: "index_tech_sheets_on_sub_order_id_and_version", unique: true
    t.index ["sub_order_id"], name: "index_tech_sheets_on_sub_order_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "clerk_id", null: false
    t.string "email"
    t.string "first_name"
    t.string "last_name"
    t.string "image_url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "role", default: "cliente", null: false
    t.bigint "client_company_id"
    t.datetime "data_consent_at"
    t.index ["clerk_id"], name: "index_users_on_clerk_id", unique: true
    t.index ["client_company_id"], name: "index_users_on_client_company_id"
    t.index ["email"], name: "index_users_on_email"
  end

  create_table "workshop_capabilities", force: :cascade do |t|
    t.bigint "workshop_id", null: false
    t.bigint "category_id", null: false
    t.string "processes"
    t.string "materials"
    t.integer "min_volume"
    t.integer "max_volume"
    t.string "tolerances"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category_id"], name: "index_workshop_capabilities_on_category_id"
    t.index ["workshop_id", "category_id"], name: "index_workshop_capabilities_on_workshop_id_and_category_id", unique: true
    t.index ["workshop_id"], name: "index_workshop_capabilities_on_workshop_id"
  end

  create_table "workshops", force: :cascade do |t|
    t.string "name", null: false
    t.string "nit"
    t.boolean "has_rut", default: false, null: false
    t.boolean "e_invoicing", default: false, null: false
    t.string "status", default: "prospecto", null: false
    t.string "level"
    t.decimal "score", precision: 4, scale: 1
    t.string "contact_name"
    t.string "phone"
    t.string "whatsapp"
    t.string "email"
    t.string "address"
    t.string "neighborhood"
    t.text "machines"
    t.text "notes"
    t.jsonb "visit_checklist", default: {}, null: false
    t.datetime "visited_at"
    t.datetime "pilot_approved_at"
    t.string "status_reason"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "commission_percent", precision: 4, scale: 2, default: "10.0", null: false
    t.text "payment_details"
    t.index ["nit"], name: "index_workshops_on_nit", unique: true, where: "(nit IS NOT NULL)"
    t.index ["status"], name: "index_workshops_on_status"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "approvals", "users"
  add_foreign_key "audit_events", "orders"
  add_foreign_key "commissions", "commission_cuts"
  add_foreign_key "commissions", "payments"
  add_foreign_key "commissions", "sub_orders"
  add_foreign_key "commissions", "workshops"
  add_foreign_key "escalations", "sub_orders"
  add_foreign_key "escalations", "workshops"
  add_foreign_key "inspection_items", "inspections"
  add_foreign_key "inspections", "inspections", column: "reinspection_of_id"
  add_foreign_key "inspections", "sub_orders"
  add_foreign_key "inspections", "users", column: "closed_by_user_id"
  add_foreign_key "milestones", "sub_orders"
  add_foreign_key "orders", "client_companies"
  add_foreign_key "orders", "requirements"
  add_foreign_key "payments", "sub_orders"
  add_foreign_key "proposals", "orders"
  add_foreign_key "proposals", "quotes"
  add_foreign_key "proposals", "tech_sheets"
  add_foreign_key "quotes", "sub_orders"
  add_foreign_key "quotes", "tech_sheets"
  add_foreign_key "quotes", "workshops"
  add_foreign_key "requirement_messages", "requirements"
  add_foreign_key "requirements", "categories"
  add_foreign_key "requirements", "client_companies"
  add_foreign_key "samples", "sub_orders"
  add_foreign_key "solid_queue_batch_executions", "solid_queue_batches", column: "batch_id", on_delete: :cascade
  add_foreign_key "solid_queue_batch_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "sub_orders", "categories"
  add_foreign_key "sub_orders", "orders"
  add_foreign_key "sub_orders", "workshops"
  add_foreign_key "tech_sheets", "sub_orders"
  add_foreign_key "users", "client_companies"
  add_foreign_key "workshop_capabilities", "categories"
  add_foreign_key "workshop_capabilities", "workshops"
end
