class AddBackendToOutbound < ActiveRecord::Migration
  def self.up
    add_column :outbounds, :backend_id, :integer
  end

  def self.down
    remove_column :outbounds, :backend_id
  end
end
