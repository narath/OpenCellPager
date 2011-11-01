class RemoveStatusColsFromPages < ActiveRecord::Migration
  def self.up
    # remove the fields which are now more properly stored in outbound
    remove_column :pages, :status
    remove_column :pages, :gateway_status_string
    remove_column :pages, :gateway_uid
  end

  def self.down
    add_column :pages, :status, :integer
    add_column :pages, :gateway_status_string, :string
    add_column :pages, :gateway_uid, :integer
  end
end
