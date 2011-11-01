class AddSendAliveToUsers < ActiveRecord::Migration
  def self.up
    add_column :users, :send_alive, :boolean, :default => false
  end

  def self.down
    remove_column :users, :send_alive
  end
end
