class RevertAdminSudoerSemantics < ActiveRecord::Migration[7.2]
  def self.up
    add_column :users, :_admin_tmp, :boolean, default: false, null: false
    execute "UPDATE users SET _admin_tmp = sudoer"
    execute "UPDATE users SET sudoer = admin"
    execute "UPDATE users SET admin = _admin_tmp"
    remove_column :users, :_admin_tmp
  end

  def self.down
    add_column :users, :_admin_tmp, :boolean, default: false, null: false
    execute "UPDATE users SET _admin_tmp = sudoer"
    execute "UPDATE users SET sudoer = admin"
    execute "UPDATE users SET admin = _admin_tmp"
    remove_column :users, :_admin_tmp
  end
end
