class AddStatusToUser < ActiveRecord::Migration
  def self.up
    add_column :users, :forward_id, :integer
    add_column :users, :status, :integer, :default=>1
    add_column :users, :note, :string
    
    execute "update users set status = 1"
  end

  def self.down
    remove_column :users, :forward_id
    remove_column :users, :status
    remove_column :users, :note
  end
end
