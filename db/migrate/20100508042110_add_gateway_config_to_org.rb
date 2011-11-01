class AddGatewayConfigToOrg < ActiveRecord::Migration
  def self.up
    add_column :orgs, :gateway_config, :string, :default=>''
  end

  def self.down
    remove_column :orgs, :gateway_config
  end
end
