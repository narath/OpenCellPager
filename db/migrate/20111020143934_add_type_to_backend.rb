class AddTypeToBackend < ActiveRecord::Migration
  def self.up
    add_column :backends, :backend_type, :string, :limit => 20
  end

  def self.down
    remove_column :backends, :backend_type
  end
end
