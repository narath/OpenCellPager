class AddStatusStringToOrg < ActiveRecord::Migration
  def self.up
    add_column :orgs, :gateway_status_string, :string
  end

  def self.down
    remove_column :orgs, :gateway_status_string
  end
end
