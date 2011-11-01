class AddConfCodeToUser < ActiveRecord::Migration
  def self.up
    add_column :users, :sms_validation_sent, :string
    add_column :users, :sms_validation_received, :string
    add_column :users, :login_name, :string
    execute "update users set login_name = unique_name"
  end

  def self.down
    remove_column :users, :sms_validation_sent
    remove_column :users, :sms_validation_received
    remove_column :users, :login_name
  end
end
