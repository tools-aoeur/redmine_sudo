# frozen_string_literal: true

class CreateSecurityAuditLogs < ActiveRecord::Migration[7.2]
  def change
    create_table :security_audit_logs do |t|
      t.integer :user_id, null: false
      t.string :user_login, null: false, limit: 255
      t.string :user_remote_ip, limit: 45
      t.string :action, null: false, limit: 255
      t.string :entity_type, limit: 255
      t.integer :entity_id
      t.string :entity_name, limit: 255
      t.text :details
      t.datetime :created_at, null: false
    end

    add_index :security_audit_logs, :user_id
    add_index :security_audit_logs, :action
    add_index :security_audit_logs, :entity_type
    add_index :security_audit_logs, :created_at
  end
end
