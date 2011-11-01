class AddGatewayTypeToOrg < ActiveRecord::Migration
  def self.up
    add_column :orgs, :gateway_type, :string, :default=>''
  end

  def self.down
    remove_column :orgs, :gateway_type
  end
end
