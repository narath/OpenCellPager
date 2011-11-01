class AddStatusToMsg < ActiveRecord::Migration
  def self.up
    add_column :msgs, :status, :integer, :default=>0
    remove_column :msgs, :gateway_status_string
    execute "update msgs set status = 0"
  end

  def self.down
    remove_column :users, :status
    add_column :msgs, :gateway_status_string, :string
    execute "update msgs set gateway_status_string = ''"
  end
end