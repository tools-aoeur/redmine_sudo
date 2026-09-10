class AddSudoerToUsers < ActiveRecord::Migration[4.2]
  def self.up
    add_column :users, :sudoer, :boolean, :default => false, :null => false
  end

  def self.down
    remove_column :users, :sudoer
  end
end
