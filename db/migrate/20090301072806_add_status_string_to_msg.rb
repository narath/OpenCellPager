class AddStatusStringToMsg < ActiveRecord::Migration
  def self.up
    add_column :msgs, :gateway_status_string, :string
  end

  def self.down
    remove_column :msgs, :gateway_status_string
  end
end
